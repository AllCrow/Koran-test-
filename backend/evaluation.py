"""Offline, explicit evaluation of declared expert labels; never runs inference.

The normal API and iPhone app do not import this module. See
docs/TAJWEED_EVALUATION.md for the corpus contract and limits of the metrics.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any

from pydantic import ValidationError

from .config import ENGINE_VERSION, MODEL_ID, MODEL_REVISION, Settings
from .reference import REFERENCE_SOURCE, ReferenceRepository, ReferenceUnavailable
from .schemas import Assessment

MAX_DOCUMENT_BYTES = 8 * 1024 * 1024
MAX_CASES = 10_000
MAX_ISSUES = 256
_IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,95}\Z")
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")


class EvaluationError(ValueError):
    """A malformed or mismatched evaluation input, before any scoring."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise EvaluationError(message)


def _object(value: Any, keys: set[str], label: str, optional: set[str] | None = None) -> dict:
    _require(isinstance(value, dict), f"{label}: expected an object")
    _require(keys <= value.keys() <= keys | (optional or set()), f"{label}: unexpected or missing fields")
    return value


def _identifier(value: Any, label: str) -> str:
    _require(isinstance(value, str) and _IDENTIFIER.fullmatch(value) is not None,
             f"{label}: invalid identifier")
    return value


def _digest(value: Any, label: str) -> str:
    _require(isinstance(value, str) and _SHA256.fullmatch(value) is not None,
             f"{label}: expected a lowercase SHA256")
    return value


def _integer(value: Any, minimum: int, maximum: int, label: str) -> int:
    _require(type(value) is int and minimum <= value <= maximum, f"{label}: invalid integer")
    return value


def _text(value: Any, label: str, maximum: int = 4_096) -> str:
    _require(isinstance(value, str) and bool(value.strip()) and len(value) <= maximum,
             f"{label}: invalid text")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError as error:
        raise EvaluationError(f"{label}: not Unicode scalar text") from error
    return value


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical_digest(document: dict) -> str:
    return _sha256(json.dumps(document, ensure_ascii=False, sort_keys=True,
                              separators=(",", ":"), allow_nan=False).encode("utf-8"))


def _unique_object(pairs: list[tuple[str, Any]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        _require(key not in result, "JSON contains a duplicate key")
        result[key] = value
    return result


def read_document(path: Path) -> tuple[dict, str]:
    """Bound the actual read (not just stat); reject duplicate keys and NaN."""
    with path.open("rb") as handle:
        raw = handle.read(MAX_DOCUMENT_BYTES + 1)
    _require(len(raw) <= MAX_DOCUMENT_BYTES, "JSON exceeds the 8 MiB limit")
    try:
        document = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_object,
                              parse_constant=lambda _: (_ for _ in ()).throw(EvaluationError("Non-finite JSON number")))
    except EvaluationError:
        raise
    except (ValueError, RecursionError) as error:
        raise EvaluationError("Invalid UTF-8 JSON") from error
    _require(isinstance(document, dict), "JSON root must be an object")
    return document, _sha256(raw)


@dataclass(frozen=True)
class Mark:
    kind: str
    category: str
    start: int
    end: int


def _mark(value: dict, length: int, label: str, *, teacher: bool) -> Mark:
    if teacher:
        _object(value, {"kind", "category", "start_scalar", "end_scalar"}, label)
    _require(value.get("kind") in ("normal", "tashkeel", "tajweed"), f"{label}: unknown kind")
    _require(value.get("category") in ("insert", "delete", "replace"), f"{label}: unknown category")
    start = _integer(value.get("start_scalar"), 0, length, label)
    end = _integer(value.get("end_scalar"), start, length, label)
    _require(start < end or value["category"] == "insert", f"{label}: only insert may have zero width")
    return Mark(value["kind"], value["category"], start, end)


def maximum_matching(predicted: list[Mark], teacher: list[Mark], *, overlap: bool) -> list[tuple[int, int]]:
    """Maximum cardinality, one-to-one; output is stable for fixed input order.

    Exact localization is primary. The overlap diagnostic uses half-open spans;
    adjacent spans never overlap and a zero-width point matches only that point.
    A greedy matcher can undercount when one broad indication overlaps two labels.
    """
    def compatible(first: Mark, second: Mark) -> bool:
        if (first.kind, first.category) != (second.kind, second.category):
            return False
        if not overlap or first.start == first.end or second.start == second.end:
            return (first.start, first.end) == (second.start, second.end)
        return max(first.start, second.start) < min(first.end, second.end)

    edges = [[j for j, expected in enumerate(teacher) if compatible(actual, expected)]
             for actual in predicted]
    owners: dict[int, int] = {}

    def augment(index: int, seen: set[int]) -> bool:
        for candidate in edges[index]:
            if candidate in seen:
                continue
            seen.add(candidate)
            if candidate not in owners or augment(owners[candidate], seen):
                owners[candidate] = index
                return True
        return False

    for index in range(len(predicted)):
        augment(index, set())
    return sorted((actual, expected) for expected, actual in owners.items())


def _rate(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def evaluate(corpus: dict, predictions: dict, *, repository: ReferenceRepository | None = None,
             audio_directory: Path | None = None) -> dict:
    """Validate every input first; pending/inconclusive cases never become truth.

    If audio_directory is given, exact original uploads must be named
    <case_id>.audio. No network access, recording or model execution occurs.
    """
    repository = repository or ReferenceRepository(Settings().resource_directory)
    _object(corpus, {"schema_version", "corpus_id", "purpose", "reference_source", "cases"}, "corpus")
    _require(type(corpus["schema_version"]) is int and corpus["schema_version"] == 1, "Unsupported corpus schema")
    _identifier(corpus["corpus_id"], "corpus_id")
    _require(corpus["purpose"] in ("synthetic_fixture", "expert_review"), "Unknown corpus purpose")
    _require(corpus["reference_source"] == REFERENCE_SOURCE, "Wrong reference edition")
    _require(isinstance(corpus["cases"], list) and 0 < len(corpus["cases"]) <= MAX_CASES, "Invalid corpus case count")
    _object(predictions, {"schema_version", "run_id", "engine_source_sha256", "cases"}, "predictions")
    _require(type(predictions["schema_version"]) is int and predictions["schema_version"] == 1, "Unsupported prediction schema")
    _identifier(predictions["run_id"], "run_id")
    _digest(predictions["engine_source_sha256"], "engine_source_sha256")
    _require(isinstance(predictions["cases"], list) and len(predictions["cases"]) <= MAX_CASES, "Invalid prediction case count")

    declared: dict[str, dict] = {}
    audio_identities: set[str] = set()
    # Fail closed before calculating totals, including for unreviewed material.
    for case in corpus["cases"]:
        _object(case, {"case_id", "audio_sha256", "audio_bytes", "reference", "review"}, "case")
        identifier = _identifier(case["case_id"], "case_id")
        _require(identifier not in declared, "Duplicate corpus case_id")
        _digest(case["audio_sha256"], "audio_sha256")
        _require(case["audio_sha256"] not in audio_identities, "Duplicate audio identity would reweight the corpus")
        audio_identities.add(case["audio_sha256"])
        _integer(case["audio_bytes"], 1, Settings().max_upload_bytes, "audio_bytes")
        reference = _object(case["reference"], {"surah_id", "ayah_number", "include_basmala", "text_sha256"}, "reference")
        _integer(reference["surah_id"], 1, 114, "surah_id")
        _integer(reference["ayah_number"], 1, 286, "ayah_number")
        _require(type(reference["include_basmala"]) is bool, "include_basmala must be Boolean")
        _digest(reference["text_sha256"], "text_sha256")
        try:
            resolved = repository.resolve(reference["surah_id"], reference["ayah_number"],
                                          include_basmala=reference["include_basmala"])
        except (ValueError, ReferenceUnavailable) as error:
            raise EvaluationError("Unavailable or invalid pinned reference") from error
        _require(reference["text_sha256"] == _sha256(resolved.text.encode("utf-8")), "Reference text SHA256 mismatch")
        review = _object(case["review"], {"status", "reviewer_ids", "blinded", "complete", "errors"}, "review", {"notes"})
        _require(review["status"] in ("pending", "inconclusive", "adjudicated"), "Unknown review status")
        _require(type(review["blinded"]) is bool and type(review["complete"]) is bool, "Review flags must be Boolean")
        _require(isinstance(review["reviewer_ids"], list) and len(review["reviewer_ids"]) <= 20, "Invalid reviewers")
        reviewers = [_identifier(value, "reviewer_id") for value in review["reviewer_ids"]]
        _require(len(set(reviewers)) == len(reviewers), "Duplicate reviewer_id")
        _require(isinstance(review["errors"], list) and len(review["errors"]) <= MAX_ISSUES, "Invalid teacher error count")
        marks = [_mark(value, len(resolved.text), "teacher error", teacher=True) for value in review["errors"]]
        _require(len(set(marks)) == len(marks), "Duplicate teacher error")
        if "notes" in review:
            _text(review["notes"], "review notes")
        if review["status"] == "adjudicated":
            _require(len(reviewers) >= 2 and review["blinded"] and review["complete"],
                     "Adjudicated cases require two independent blinded reviewers and a complete review")
        else:
            _require(not marks and not review["complete"], "Unresolved cases cannot supply ground truth")
        if audio_directory is not None:
            path = audio_directory / f"{identifier}.audio"
            _require(not path.is_symlink(), "Audio input must not be a symlink")
            _require(path.is_file(), "Audio input must be a regular file")
            _require(path.is_file(), "Audio input must be a regular file")
            try:
                with path.open("rb") as handle:
                    audio = handle.read(Settings().max_upload_bytes + 1)
            except OSError as error:
                raise EvaluationError(f"Original upload unavailable for {identifier}") from error
            _require(len(audio) == case["audio_bytes"] and _sha256(audio) == case["audio_sha256"],
                     f"Original upload identity mismatch for {identifier}")
        declared[identifier] = {"input": case, "resolved": resolved, "marks": marks}

    actual: dict[str, dict] = {}
    for prediction in predictions["cases"]:
        _object(prediction, {"case_id", "audio_sha256", "audio_bytes", "assessment"}, "prediction")
        identifier = _identifier(prediction["case_id"], "prediction case_id")
        _require(identifier in declared, "Prediction case_id is absent from corpus")
        _require(identifier not in actual, "Duplicate prediction case_id")
        case = declared[identifier]
        _require(prediction["audio_sha256"] == case["input"]["audio_sha256"] and
                 type(prediction["audio_bytes"]) is int and prediction["audio_bytes"] == case["input"]["audio_bytes"],
                 "Prediction audio identity mismatch")
        payload = _object(prediction["assessment"], set(Assessment.model_fields), "assessment")
        _require(type(payload["schema_version"]) is int and payload["schema_version"] == 1 and
                 payload["experimental"] is True, "Invalid assessment schema/experimental flag")
        try:
            assessment = Assessment.model_validate(payload, strict=True)
        except ValidationError as error:
            raise EvaluationError("Invalid assessment contract") from error
        resolved = case["resolved"]
        _require(assessment.reference == resolved.identifier and assessment.reference_text == resolved.text and
                 assessment.reference_source == REFERENCE_SOURCE and
                 assessment.reference_scalar_offset == resolved.scalar_offset and
                 assessment.include_basmala == resolved.include_basmala, "Assessment reference mismatch")
        _require(assessment.model == MODEL_ID and assessment.model_revision == MODEL_REVISION and
                 assessment.engine_version == ENGINE_VERSION, "Assessment model/version mismatch")
        _require(len(assessment.issues) <= MAX_ISSUES, "Too many predicted issues")
        _require(assessment.status == "assessed" or not assessment.issues, "Abstention contains issues")
        strings = [assessment.message, *assessment.assumptions]
        strings.extend(text for issue in assessment.issues
                       for text in (issue.expected, issue.observed, issue.message))
        try:
            _require(all(len(value) <= 32_768 for value in strings), "Assessment text is too long")
            for value in strings:
                value.encode("utf-8")
        except UnicodeEncodeError as error:
            raise EvaluationError("Assessment contains invalid Unicode scalars") from error
        marks = [_mark(value.model_dump(), len(resolved.text), "predicted issue", teacher=False)
                 for value in assessment.issues]
        # Duplicate predictions remain visible and count as excess corrections.
        actual[identifier] = {"assessment": assessment, "marks": marks}

    totals = dict(cases=len(declared), pending=0, inconclusive=0, adjudicated=0,
                  assessed=0, unavailable=0, insufficient_audio=0, missing_predictions=0,
                  teacher_errors=0, teacher_errors_in_assessed=0,
                  teacher_errors_in_abstained=0, teacher_errors_in_missing=0,
                  error_free_clips=0, assessed_error_free_clips=0,
                  error_free_clips_with_indications=0)
    counts = {name: dict(matched=0, false_indications=0, missed_errors=0,
                        by_kind={kind: dict(matched=0, false_indications=0, missed_errors=0)
                                 for kind in ("normal", "tashkeel", "tajweed")})
              for name in ("exact", "overlap_diagnostic")}
    case_results = []
    for identifier, case in declared.items():
        status = case["input"]["review"]["status"]
        totals[status] += 1
        prediction = actual.get(identifier)
        result = {"case_id": identifier, "review_status": status,
                  "assessment_status": prediction["assessment"].status if prediction else "missing",
                  "scored": status == "adjudicated"}
        case_results.append(result)
        if status != "adjudicated":
            continue
        expected = case["marks"]
        observed = prediction["marks"] if prediction else []
        totals["teacher_errors"] += len(expected)
        if not expected:
            totals["error_free_clips"] += 1
        if prediction is None:
            totals["missing_predictions"] += 1
            totals["teacher_errors_in_missing"] += len(expected)
        else:
            state = prediction["assessment"].status
            totals[state] += 1
            if state == "assessed":
                totals["teacher_errors_in_assessed"] += len(expected)
                if not expected:
                    totals["assessed_error_free_clips"] += 1
                    totals["error_free_clips_with_indications"] += bool(observed)
            else:
                totals["teacher_errors_in_abstained"] += len(expected)
        for policy in counts:
            pairs = maximum_matching(observed, expected, overlap=policy == "overlap_diagnostic")
            paired_actual = {value[0] for value in pairs}
            paired_expected = {value[1] for value in pairs}
            unmatched_actual = [i for i in range(len(observed)) if i not in paired_actual]
            unmatched_expected = [i for i in range(len(expected)) if i not in paired_expected]
            counts[policy]["matched"] += len(pairs)
            counts[policy]["false_indications"] += len(unmatched_actual)
            counts[policy]["missed_errors"] += len(unmatched_expected)
            for _, expected_index in pairs:
                counts[policy]["by_kind"][expected[expected_index].kind]["matched"] += 1
            for index in unmatched_actual:
                counts[policy]["by_kind"][observed[index].kind]["false_indications"] += 1
            for index in unmatched_expected:
                counts[policy]["by_kind"][expected[index].kind]["missed_errors"] += 1
            result[policy] = {"pairs": [list(pair) for pair in pairs],
                              "unmatched_predicted_indices": unmatched_actual,
                              "unmatched_teacher_indices": unmatched_expected}

    # Fixtures exercise arithmetic, never produce an acoustic quality result.
    metrics = None
    if corpus["purpose"] == "expert_review" and totals["adjudicated"]:
        exact = counts["exact"]
        metrics = {
            "precision": _rate(exact["matched"], exact["matched"] + exact["false_indications"]),
            "recall_including_abstentions_and_missing": _rate(exact["matched"], totals["teacher_errors"]),
            "recall_on_assessed_only": _rate(exact["matched"], totals["teacher_errors_in_assessed"]),
            "f1_including_abstentions_and_missing": _rate(2 * exact["matched"],
                2 * exact["matched"] + exact["false_indications"] + exact["missed_errors"]),
            "assessment_coverage": _rate(totals["assessed"], totals["adjudicated"]),
            "error_free_clip_false_correction_rate_on_assessed": _rate(
                totals["error_free_clips_with_indications"], totals["assessed_error_free_clips"]),
        }
    return {
        "schema_version": 1, "corpus_id": corpus["corpus_id"], "run_id": predictions["run_id"],
        "purpose": corpus["purpose"], "corpus_canonical_sha256": _canonical_digest(corpus),
        "predictions_canonical_sha256": _canonical_digest(predictions),
        "engine_source_sha256": predictions["engine_source_sha256"],
        "model": MODEL_ID, "model_revision": MODEL_REVISION, "engine_version": ENGINE_VERSION,
        "reference_source": REFERENCE_SOURCE,
        "matching_policy": {
            "primary": "exact kind, category and half-open Unicode scalar span",
            "diagnostic": "same kind/category and nonempty half-open overlap; points match only equal points",
            "assignment": "maximum-cardinality one-to-one",
            "scope": "indication classification/localization only; not rule identity, phoneme correctness or feedback quality",
        },
        "original_audio_verified_locally": audio_directory is not None,
        "review_coverage": _rate(totals["adjudicated"], totals["cases"]),
        "totals": totals, "matching_counts": counts, "quality_metrics": metrics,
        "cases": case_results,
        "limitations": [
            "Reviewer credentials, independence and completeness are declarations, not verified by this tool.",
            "Metrics cover only declared adjudicated cases; unresolved cases are excluded, not correct negatives.",
            "Exact kind, category and scalar span are the primary matching rule; overlap is diagnostic only.",
            "A matched indication does not validate the tajweed rule, expected/observed phonemes or suggested feedback.",
            "Absent original audio verification, identity is a matching recorded hash, not rechecked audio bytes.",
            "No population accuracy, religious correctness, full sifat coverage or Tarteel parity is established.",
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", required=True, type=Path)
    parser.add_argument("--predictions", required=True, type=Path)
    parser.add_argument("--audio-directory", type=Path,
                        help="Optionally recheck every exact upload as <case_id>.audio; never uploads files")
    parser.add_argument("--output", type=Path, help="Write report here, otherwise stdout; existing files are refused")
    args = parser.parse_args(argv)
    try:
        corpus, corpus_digest = read_document(args.corpus)
        predictions, prediction_digest = read_document(args.predictions)
        report = evaluate(corpus, predictions, audio_directory=args.audio_directory)
        report["input_file_sha256"] = {"corpus": corpus_digest, "predictions": prediction_digest}
        report["evaluator_source_sha256"] = _sha256(Path(__file__).read_bytes())
        rendered = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
        if args.output:
            # Refuse accidental overwrites of source evidence, labels or audio.
            with args.output.open("x", encoding="utf-8") as handle:
                handle.write(rendered)
        else:
            sys.stdout.write(rendered)
        return 0
    except (EvaluationError, OSError) as error:
        print(f"Evaluation refused: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
