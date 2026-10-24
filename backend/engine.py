from __future__ import annotations

from threading import Lock
from typing import Protocol

from .audio import DecodedAudio, InsufficientAudio
from .config import MODEL_ID, MODEL_REVISION, Settings
from .schemas import Issue


class AssessmentEngine(Protocol):
    @property
    def ready(self) -> bool: ...

    def assess(self, audio: DecodedAudio, reference_text: str) -> list[Issue]: ...


def is_accepted_arid_variant(error) -> bool:
    """Accept only the established 2/4/6 lengths of the same arid long vowel.

    The pinned transcript library identifies the rule by a concrete dataclass,
    not by its translated display name. A normal/tashkeel error, another rule,
    another vowel, or a mixed rule violation must remain visible.
    """
    from quran_transcript.phonetics.tajweed_rulses import AaredMaddRule

    rules = error.ref_tajweed_rules or []
    if error.error_type != "tajweed" or error.speech_error_type != "replace":
        return False
    if len(rules) != 1 or type(rules[0]) is not AaredMaddRule:
        return False
    if any((error.inserted_tajweed_rules, error.replaced_tajweed_rules, error.missing_tajweed_rules)):
        return False
    rule = rules[0]
    expected = error.expected_ph
    observed = error.preditected_ph
    if not expected or not observed:
        return False
    vowel_tags = {"ا": "alif", "ۥ": "waw", "ۦ": "yaa"}
    vowel = expected[0]
    if vowel not in vowel_tags or rule.tag != vowel_tags[vowel] or rule.correctness_type != "count":
        return False
    if set(expected) != {vowel} or set(observed) != {vowel}:
        return False
    allowed_lengths = {2, 4, 6}
    return (
        len(expected) in allowed_lengths
        and len(observed) in allowed_lengths
        and rule.golden_len == len(expected)
        and error.expected_len == len(expected)
        and error.predicted_len == len(observed)
    )


class MuaalemEngine:
    """Pinned acoustic model + its phonetic error explainer. No text-ASR proxy."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self._model = None
        self._lock = Lock()
        self.load_error: str | None = None

    @property
    def ready(self) -> bool:
        return self._model is not None

    def load(self) -> None:
        """Called explicitly at startup, never implicitly for an uploaded recording."""
        try:
            import torch
            from huggingface_hub import snapshot_download
            from quran_muaalem import Muaalem

            path = snapshot_download(
                repo_id=MODEL_ID,
                revision=MODEL_REVISION,
                local_files_only=self.settings.model_local_files_only,
            )
            model = Muaalem(model_name_or_path=path, device=self.settings.model_device, dtype=torch.float32)
            model.model.eval()
            self._model = model
            self.load_error = None
        except Exception as error:
            # Store only the exception type; paths, tokens and uploaded audio are
            # never placed into HTTP errors or logs.
            self.load_error = type(error).__name__
            self._model = None

    def assess(self, audio: DecodedAudio, reference_text: str) -> list[Issue]:
        if self._model is None:
            raise RuntimeError("Model unavailable")
        import numpy as np
        import torch
        from quran_transcript import MoshafAttributes, explain_error, quran_phonetizer

        attributes = MoshafAttributes(
            rewaya="hafs",
            madd_monfasel_len=4,
            madd_mottasel_len=4,
            madd_mottasel_waqf=4,
            madd_aared_len=4,
        )
        reference = quran_phonetizer(reference_text, attributes, remove_spaces=True)
        vocabulary = self._model.multi_level_tokenizer.vocab["phonemes"]
        if any(character not in vocabulary for character in reference.phonemes):
            # Never silently discard Uthmani signs to force a reference into a
            # model trained on another edition.
            raise ValueError("Reference phonemes are outside the pinned model vocabulary")
        samples = np.asarray(audio.samples, dtype=np.float32)
        # Also protects the model if an HTTP request is cancelled while its
        # worker thread is still completing inference.
        with self._lock, torch.inference_mode():
            result = self._model([samples], [reference], sampling_rate=audio.sample_rate)[0]
        predicted = result.phonemes.text
        if not isinstance(predicted, str) or not predicted.strip():
            raise InsufficientAudio("Modellen kunde inte urskilja recitationen. Spela in en tydligare fras.")
        errors = explain_error(
            uthmani_text=reference_text,
            ref_ph_text=reference.phonemes,
            predicted_ph_text=predicted,
            mappings=reference.mappings,
        )
        issues: list[Issue] = []
        for error in errors:
            start, end = error.uthmani_pos
            if not (0 <= start <= end <= len(reference_text)):
                # Do not present an acoustic result mapped outside its exact
                # reference edition, or invent a position by clamping it.
                raise ValueError("Invalid model-to-reference mapping")
            if is_accepted_arid_variant(error):
                continue
            names: list[str] = []
            for rule in error.ref_tajweed_rules or []:
                name = getattr(getattr(rule, "name", None), "en", None)
                if isinstance(name, str) and name not in names:
                    names.append(name)
            messages = {
                "normal": "Modellen indikerar en möjlig skillnad i uttalet.",
                "tashkeel": "Modellen indikerar en möjlig skillnad i vokaliseringen.",
                "tajweed": "Modellen indikerar en möjlig tajweedavvikelse" + (": " + ", ".join(names) if names else "") + ".",
            }
            issues.append(Issue(
                kind=error.error_type,
                category=error.speech_error_type,
                start_scalar=start,
                end_scalar=end,
                expected=error.expected_ph,
                observed=error.preditected_ph,  # Public upstream spelling.
                message=messages[error.error_type],
            ))
        return issues
