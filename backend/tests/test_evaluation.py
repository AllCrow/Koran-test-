"""Synthetic evaluation-contract tests, not acoustic or expert-quality results."""
from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest

from backend.config import Settings
from backend.evaluation import EvaluationError, Mark, evaluate, main, maximum_matching, read_document
from backend.reference import REFERENCE_SOURCE, ReferenceRepository
from backend.schemas import Assessment, Issue


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def mark(start: int = 0, end: int = 1, *, kind: str = "tajweed", category: str = "replace") -> dict:
    return dict(kind=kind, category=category, start_scalar=start, end_scalar=end)


class EvaluationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repository = ReferenceRepository(Settings().resource_directory)
        cls.reference = cls.repository.resolve(1, 1, include_basmala=False)

    def fixture(self, *, expected=None, observed=None, review_status="adjudicated", assessment_status="assessed"):
        expected = [] if expected is None else expected
        observed = [] if observed is None else observed
        corpus = dict(schema_version=1, corpus_id="synthetic-tests", purpose="synthetic_fixture",
                      reference_source=REFERENCE_SOURCE, cases=[])
        predictions = dict(schema_version=1, run_id="synthetic-run", engine_source_sha256="a" * 64, cases=[])
        self.add_case(corpus, predictions, "fixture-1", expected, observed, review_status, assessment_status)
        return corpus, predictions

    def add_case(self, corpus, predictions, identifier, expected, observed, review_status="adjudicated",
                 assessment_status="assessed"):
        # These bytes and reviewer identifiers are artificial test data only.
        audio = f"synthetic non-audio {identifier}".encode()
        reference = dict(surah_id=1, ayah_number=1, include_basmala=False,
                         text_sha256=digest(self.reference.text.encode()))
        adjudicated = review_status == "adjudicated"
        review = dict(status=review_status, reviewer_ids=["fixture-a", "fixture-b"] if adjudicated else [],
                      blinded=adjudicated, complete=adjudicated, errors=expected,
                      notes="Synthetic fixture; not an expert review or acoustic sample.")
        corpus["cases"].append(dict(case_id=identifier, audio_sha256=digest(audio), audio_bytes=len(audio),
                                    reference=reference, review=review))
        issues = [Issue(**value, expected="test", observed="test", message="Synthetic indication") for value in observed]
        assessment = Assessment(status=assessment_status, reference=self.reference.identifier,
                                reference_text=self.reference.text, reference_scalar_offset=self.reference.scalar_offset,
                                include_basmala=False, issues=issues, message="Synthetic assessment")
        predictions["cases"].append(dict(case_id=identifier, audio_sha256=digest(audio), audio_bytes=len(audio),
                                         assessment=assessment.model_dump()))

    def test_fixtures_never_publish_quality_metrics(self):
        corpus, predictions = self.fixture(expected=[mark()], observed=[mark()])
        result = evaluate(corpus, predictions)
        self.assertEqual(result["matching_counts"]["exact"]["matched"], 1)
        self.assertIsNone(result["quality_metrics"])
        self.assertEqual(result["purpose"], "synthetic_fixture")
        self.assertFalse(result["original_audio_verified_locally"])

    def test_pending_and_inconclusive_are_not_correct_negatives(self):
        corpus, predictions = self.fixture(review_status="pending", observed=[mark()])
        self.add_case(corpus, predictions, "fixture-2", [], [], "inconclusive")
        result = evaluate(corpus, predictions)
        self.assertEqual(result["totals"]["adjudicated"], 0)
        self.assertEqual(result["totals"]["pending"], 1)
        self.assertEqual(result["totals"]["inconclusive"], 1)
        self.assertEqual(result["matching_counts"]["exact"]["false_indications"], 0)
        self.assertTrue(all(not value["scored"] for value in result["cases"]))
        self.assertIsNone(result["quality_metrics"])

    def test_abstentions_and_missing_predictions_remain_in_recall_denominator(self):
        corpus, predictions = self.fixture(expected=[mark()], observed=[mark()])
        self.add_case(corpus, predictions, "fixture-2", [mark()], [], assessment_status="unavailable")
        self.add_case(corpus, predictions, "fixture-3", [mark()], [], assessment_status="insufficient_audio")
        self.add_case(corpus, predictions, "fixture-4", [mark()], [])
        predictions["cases"].pop()
        self.add_case(corpus, predictions, "fixture-5", [], [mark()])
        self.add_case(corpus, predictions, "fixture-6", [], [], "pending")
        # Exercise metric arithmetic under an artificial expert-review declaration.
        # This fixture never becomes a saved acoustic/expert evaluation.
        corpus["purpose"] = "expert_review"
        result = evaluate(corpus, predictions)
        counts = result["matching_counts"]["exact"]
        self.assertEqual((counts["matched"], counts["false_indications"], counts["missed_errors"]), (1, 1, 3))
        totals = result["totals"]
        self.assertEqual((totals["teacher_errors_in_abstained"], totals["teacher_errors_in_missing"]), (2, 1))
        self.assertEqual(totals["adjudicated"], 5)
        self.assertEqual(result["review_coverage"], 5 / 6)
        metrics = result["quality_metrics"]
        self.assertEqual(metrics["precision"], .5)
        self.assertEqual(metrics["recall_including_abstentions_and_missing"], .25)
        self.assertEqual(metrics["recall_on_assessed_only"], 1)
        self.assertEqual(metrics["assessment_coverage"], 2 / 5)
        self.assertEqual(metrics["error_free_clip_false_correction_rate_on_assessed"], 1)

    def test_zero_denominators_are_null_not_perfect_scores(self):
        corpus, predictions = self.fixture(assessment_status="unavailable")
        corpus["purpose"] = "expert_review"
        result = evaluate(corpus, predictions)
        metrics = result["quality_metrics"]
        self.assertIsNone(metrics["precision"])
        self.assertIsNone(metrics["recall_including_abstentions_and_missing"])
        self.assertIsNone(metrics["recall_on_assessed_only"])
        self.assertIsNone(metrics["error_free_clip_false_correction_rate_on_assessed"])
        self.assertEqual(metrics["assessment_coverage"], 0)

    def test_duplicate_predictions_are_excess_corrections_not_extra_matches(self):
        corpus, predictions = self.fixture(expected=[mark()], observed=[mark(), mark()])
        result = evaluate(corpus, predictions)
        counts = result["matching_counts"]["exact"]
        self.assertEqual((counts["matched"], counts["false_indications"]), (1, 1))
        self.assertEqual(counts["by_kind"]["tajweed"]["false_indications"], 1)

    def test_maximum_matching_reassigns_a_broad_overlap_instead_of_greedy_loss(self):
        teacher = [Mark("tajweed", "replace", 0, 2), Mark("tajweed", "replace", 3, 5)]
        predicted = [Mark("tajweed", "replace", 0, 5), Mark("tajweed", "replace", 0, 2)]
        self.assertEqual(maximum_matching(predicted, teacher, overlap=True), [(0, 1), (1, 0)])
        self.assertEqual(maximum_matching(predicted, teacher, overlap=False), [(1, 0)])

    def test_half_open_boundaries_and_zero_width_insertions_are_unambiguous(self):
        left = Mark("tajweed", "replace", 0, 2)
        adjacent = Mark("tajweed", "replace", 2, 3)
        self.assertEqual(maximum_matching([left], [adjacent], overlap=True), [])
        point = Mark("normal", "insert", 2, 2)
        other_point = Mark("normal", "insert", 3, 3)
        covering = Mark("normal", "insert", 1, 3)
        self.assertEqual(maximum_matching([point], [point], overlap=True), [(0, 0)])
        self.assertEqual(maximum_matching([point], [other_point, covering], overlap=True), [])

    def test_kind_and_category_must_match_even_when_spans_match(self):
        corpus, predictions = self.fixture(expected=[mark()], observed=[mark(kind="normal"), mark(category="delete")])
        result = evaluate(corpus, predictions)["matching_counts"]["exact"]
        self.assertEqual((result["matched"], result["false_indications"], result["missed_errors"]), (0, 2, 1))
        self.assertEqual(result["by_kind"]["normal"]["false_indications"], 1)

    def test_exact_metrics_are_not_replaced_by_looser_overlap_diagnostics(self):
        corpus, predictions = self.fixture(expected=[mark(0, 2)], observed=[mark(0, 3)])
        result = evaluate(corpus, predictions)
        self.assertEqual(result["matching_counts"]["exact"]["matched"], 0)
        self.assertEqual(result["matching_counts"]["overlap_diagnostic"]["matched"], 1)

    def test_incomplete_or_unblinded_adjudications_are_refused(self):
        for mutate in (lambda review: review.update(complete=False), lambda review: review.update(blinded=False),
                       lambda review: review.update(reviewer_ids=["one-reviewer"]),
                       lambda review: review.update(reviewer_ids=["same", "same"])):
            with self.subTest(mutate=mutate):
                corpus, predictions = self.fixture()
                mutate(corpus["cases"][0]["review"])
                with self.assertRaises(EvaluationError):
                    evaluate(corpus, predictions)

    def test_unresolved_labels_and_duplicate_teacher_errors_are_refused(self):
        corpus, predictions = self.fixture(review_status="pending")
        corpus["cases"][0]["review"]["errors"] = [mark()]
        with self.assertRaisesRegex(EvaluationError, "Unresolved"):
            evaluate(corpus, predictions)
        corpus, predictions = self.fixture(expected=[mark(), mark()])
        with self.assertRaisesRegex(EvaluationError, "Duplicate teacher"):
            evaluate(corpus, predictions)

    def test_duplicate_ids_unknown_predictions_and_duplicate_audio_are_refused(self):
        for target, mutation in (
            ("corpus", lambda value: value["cases"].append(deepcopy(value["cases"][0]))),
            ("predictions", lambda value: value["cases"].append(deepcopy(value["cases"][0]))),
            ("predictions", lambda value: value["cases"][0].update(case_id="unknown")),
        ):
            with self.subTest(target=target):
                corpus, predictions = self.fixture()
                mutation(corpus if target == "corpus" else predictions)
                with self.assertRaises(EvaluationError):
                    evaluate(corpus, predictions)
        corpus, predictions = self.fixture()
        self.add_case(corpus, predictions, "fixture-2", [], [])
        corpus["cases"][1]["audio_sha256"] = corpus["cases"][0]["audio_sha256"]
        with self.assertRaisesRegex(EvaluationError, "Duplicate audio"):
            evaluate(corpus, predictions)

    def test_foreign_edition_changed_text_and_wrong_basmala_are_refused(self):
        for mutation in (
            lambda c, p: c.update(reference_source="different-edition"),
            lambda c, p: c["cases"][0]["reference"].update(text_sha256="f" * 64),
            lambda c, p: p["cases"][0]["assessment"].update(reference_text=self.reference.text.replace("ِ", "")),
            lambda c, p: p["cases"][0]["assessment"].update(include_basmala=True),
            lambda c, p: p["cases"][0]["assessment"].update(reference_scalar_offset=1),
            lambda c, p: p["cases"][0]["assessment"].update(model_revision="f" * 40),
        ):
            with self.subTest(mutation=mutation):
                corpus, predictions = self.fixture()
                mutation(corpus, predictions)
                with self.assertRaises(EvaluationError):
                    evaluate(corpus, predictions)

    def test_missing_model_metadata_never_uses_schema_defaults(self):
        for field in ("model_revision", "engine_version", "reference_source", "experimental"):
            with self.subTest(field=field):
                corpus, predictions = self.fixture()
                del predictions["cases"][0]["assessment"][field]
                with self.assertRaises(EvaluationError):
                    evaluate(corpus, predictions)

    def test_bool_integer_coercion_unknown_fields_and_bad_scalar_ranges_are_refused(self):
        for mutation in (
            lambda c, p: c.update(schema_version=True),
            lambda c, p: c["cases"][0]["reference"].update(surah_id=True),
            lambda c, p: c["cases"][0]["reference"].update(include_basmala=0),
            lambda c, p: p["cases"][0]["assessment"].update(schema_version=True),
            lambda c, p: c["cases"][0]["review"]["errors"][0].update(start_scalar=True),
            lambda c, p: c["cases"][0]["review"]["errors"][0].update(end_scalar=len(self.reference.text) + 1),
            lambda c, p: c["cases"][0]["review"]["errors"][0].update(end_scalar=0),
            lambda c, p: c["cases"][0].update(typo="must fail"),
        ):
            with self.subTest(mutation=mutation):
                corpus, predictions = self.fixture(expected=[mark()])
                mutation(corpus, predictions)
                with self.assertRaises(EvaluationError):
                    evaluate(corpus, predictions)

    def test_abstentions_cannot_hide_issues_and_invalid_unicode_is_refused(self):
        corpus, predictions = self.fixture(observed=[mark()], assessment_status="unavailable")
        with self.assertRaisesRegex(EvaluationError, "Abstention"):
            evaluate(corpus, predictions)
        corpus, predictions = self.fixture(observed=[mark()])
        predictions["cases"][0]["assessment"]["issues"][0]["observed"] = "\ud800"
        with self.assertRaisesRegex(EvaluationError, "Unicode"):
            evaluate(corpus, predictions)

    def test_prediction_audio_hash_and_size_must_both_match(self):
        for key, value in (("audio_sha256", "b" * 64), ("audio_bytes", 1), ("audio_bytes", True)):
            with self.subTest(key=key, value=value):
                corpus, predictions = self.fixture()
                predictions["cases"][0][key] = value
                with self.assertRaisesRegex(EvaluationError, "audio identity"):
                    evaluate(corpus, predictions)

    def test_optional_original_upload_verification_checks_bytes_and_refuses_symlink(self):
        corpus, predictions = self.fixture()
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            audio = folder / "fixture-1.audio"
            audio.write_bytes(b"synthetic non-audio fixture-1")
            self.assertTrue(evaluate(corpus, predictions, audio_directory=folder)["original_audio_verified_locally"])
            audio.write_bytes(b"wrong bytes")
            with self.assertRaisesRegex(EvaluationError, "identity mismatch"):
                evaluate(corpus, predictions, audio_directory=folder)
            other = folder / "other"
            audio.rename(other)
            audio.symlink_to(other)
            with self.assertRaisesRegex(EvaluationError, "symlink"):
                evaluate(corpus, predictions, audio_directory=folder)
            audio.unlink()
            audio.mkdir()
            with self.assertRaisesRegex(EvaluationError, "regular file"):
                evaluate(corpus, predictions, audio_directory=folder)
            audio.rmdir()
            if hasattr(os, "mkfifo"):
                os.mkfifo(audio)
                with self.assertRaisesRegex(EvaluationError, "regular file"):
                    evaluate(corpus, predictions, audio_directory=folder)

    def test_json_parser_refuses_duplicate_keys_nan_and_actual_oversized_read(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "input.json"
            for raw in (b'{"cases":[],"cases":[]}', b'{"value":NaN}', b'\xff',
                        '{"cases":[]}'.encode("utf-16"),
                        b'{"schema_version":' + b"9" * 5_000 + b"}",
                        b"[" * 3_000 + b"]" * 3_000,
                        b" " * (8 * 1024 * 1024 + 1)):
                with self.subTest(raw_prefix=raw[:30]):
                    path.write_bytes(raw)
                    with self.assertRaises(EvaluationError):
                        read_document(path)

    def test_cli_is_usable_without_model_or_network_and_refuses_output_overwrite(self):
        corpus, predictions = self.fixture(review_status="pending")
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            corpus_file, predictions_file, output = (folder / name for name in ("corpus.json", "predictions.json", "result.json"))
            corpus_file.write_text(json.dumps(corpus), encoding="utf-8")
            predictions_file.write_text(json.dumps(predictions), encoding="utf-8")
            args = ["--corpus", str(corpus_file), "--predictions", str(predictions_file), "--output", str(output)]
            self.assertEqual(main(args), 0)
            saved = output.read_bytes()
            self.assertIsNone(json.loads(saved)["quality_metrics"])
            with redirect_stderr(io.StringIO()):
                self.assertEqual(main(args), 2)
            self.assertEqual(output.read_bytes(), saved)
            with redirect_stdout(io.StringIO()) as captured:
                self.assertEqual(main(args[:-2]), 0)
            self.assertIn("input_file_sha256", json.loads(captured.getvalue()))

    def test_archived_pending_case_remains_unscored(self):
        root = Path(__file__).resolve().parents[2]
        corpus, _ = read_document(root / "docs/evidence/evaluation-pending-112-2-corpus.json")
        predictions, _ = read_document(root / "docs/evidence/evaluation-pending-112-2-predictions.json")
        result = evaluate(corpus, predictions)
        self.assertEqual(result["totals"]["pending"], 1)
        self.assertEqual(result["totals"]["adjudicated"], 0)
        self.assertEqual(result["review_coverage"], 0)
        self.assertIsNone(result["quality_metrics"])
        self.assertFalse(result["original_audio_verified_locally"])


if __name__ == "__main__":
    unittest.main()
