"""Regression for the actual Minshawi 1:1 false indication.

This runs the pinned real phoneticizer/error explainer, with controlled phonetic
predictions reproducing the observed 4-versus-2 result. It performs no acoustic
inference and makes no claim about general model accuracy.
"""
from __future__ import annotations

from dataclasses import replace
import unittest

from quran_transcript import Aya, MoshafAttributes, explain_error, quran_phonetizer
from quran_transcript.phonetics.tajweed_rulses import AaredMaddRule, NormalMaddRule

from backend.engine import is_accepted_arid_variant


class AridVariantRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = Aya(1, 1).get().uthmani
        attributes = MoshafAttributes(
            rewaya="hafs", madd_monfasel_len=4, madd_mottasel_len=4,
            madd_mottasel_waqf=4, madd_aared_len=4,
        )
        cls.reference = quran_phonetizer(cls.text, attributes, remove_spaces=True)
        cls.example = cls.errors_for("ۦۦ")[0]

    @classmethod
    def errors_for(cls, observed_vowel):
        # In this actual reference there is exactly one four-yaa arid group.
        assert cls.reference.phonemes.count("ۦۦۦۦ") == 1
        predicted = cls.reference.phonemes.replace("ۦۦۦۦ", observed_vowel, 1)
        return explain_error(
            uthmani_text=cls.text,
            ref_ph_text=cls.reference.phonemes,
            predicted_ph_text=predicted,
            mappings=cls.reference.mappings,
        )

    def test_actual_minshawi_two_harakat_and_valid_six_are_accepted(self):
        for length in (2, 6):
            errors = self.errors_for("ۦ" * length)
            self.assertEqual(len(errors), 1)
            error = errors[0]
            self.assertEqual(error.uthmani_pos, (36, 37))
            self.assertEqual(error.expected_ph, "ۦۦۦۦ")
            self.assertEqual(error.preditected_ph, "ۦ" * length)
            self.assertIs(type(error.ref_tajweed_rules[0]), AaredMaddRule)
            self.assertTrue(is_accepted_arid_variant(error))

    def test_baseline_four_harakat_is_accepted_without_a_correction(self):
        self.assertEqual(self.errors_for("ۦ" * 4), [])

    def test_invalid_one_three_and_five_lengths_remain_indications(self):
        for length in (1, 3, 5):
            errors = self.errors_for("ۦ" * length)
            self.assertTrue(errors)
            self.assertTrue(all(not is_accepted_arid_variant(error) for error in errors))

    def test_different_long_vowel_is_never_accepted_as_a_length_variant(self):
        for vowel in ("ا", "ۥ"):
            errors = self.errors_for(vowel * 2)
            self.assertTrue(errors)
            self.assertTrue(all(not is_accepted_arid_variant(error) for error in errors))
        same_length_wrong_vowel = replace(self.example, preditected_ph="ۥۥ", predicted_len=2)
        self.assertFalse(is_accepted_arid_variant(same_length_wrong_vowel))

    def test_another_rule_is_not_hidden_even_with_a_matching_display_name(self):
        other = NormalMaddRule(golden_len=4, tag="yaa")
        other.name = self.example.ref_tajweed_rules[0].name
        self.assertFalse(is_accepted_arid_variant(replace(self.example, ref_tajweed_rules=[other])))

    def test_mixed_rules_and_other_error_classes_are_not_hidden(self):
        other = NormalMaddRule(tag="yaa")
        for error in [
            replace(self.example, error_type="normal"),
            replace(self.example, error_type="tashkeel"),
            replace(self.example, speech_error_type="delete"),
            replace(self.example, ref_tajweed_rules=[self.example.ref_tajweed_rules[0], other]),
            replace(self.example, inserted_tajweed_rules=[other]),
            replace(self.example, replaced_tajweed_rules=[other]),
            replace(self.example, missing_tajweed_rules=[other]),
            replace(self.example, preditected_ph="ۦا", predicted_len=2),
        ]:
            self.assertFalse(is_accepted_arid_variant(error))

    def test_rule_tag_and_length_metadata_must_agree(self):
        for error in [
            replace(self.example, expected_len=2),
            replace(self.example, predicted_len=4),
            replace(self.example, ref_tajweed_rules=[AaredMaddRule(tag="waw")]),
            replace(self.example, ref_tajweed_rules=[AaredMaddRule(tag="yaa", golden_len=2)]),
        ]:
            self.assertFalse(is_accepted_arid_variant(error))

    def test_all_three_typed_long_vowel_tags_allow_only_established_lengths(self):
        for vowel, tag in [("ا", "alif"), ("ۥ", "waw"), ("ۦ", "yaa")]:
            for length in (2, 4, 6):
                error = replace(
                    self.example, expected_ph=vowel * 4, preditected_ph=vowel * length,
                    expected_len=4, predicted_len=length,
                    ref_tajweed_rules=[AaredMaddRule(tag=tag)],
                )
                self.assertTrue(is_accepted_arid_variant(error))


if __name__ == "__main__":
    unittest.main()
