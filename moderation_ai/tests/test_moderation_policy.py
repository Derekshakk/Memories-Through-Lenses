"""School photo policy over the AWS Rekognition v7 moderation taxonomy."""

import math

import moderation_policy
import pytest
from moderation_policy import (
    POLICY_VERSION,
    TAXONOMY,
    AmbiguousLabels,
    InvalidLabels,
    Label,
    evaluate,
)

# Every label in AWS's published v7 taxonomy table (docs, 2026-09).
AWS_V7_LABELS = {
    "Explicit": None,
    "Explicit Nudity": "Explicit",
    "Exposed Male Genitalia": "Explicit Nudity",
    "Exposed Female Genitalia": "Explicit Nudity",
    "Exposed Buttocks or Anus": "Explicit Nudity",
    "Exposed Female Nipple": "Explicit Nudity",
    "Explicit Sexual Activity": "Explicit",
    "Sex Toys": "Explicit",
    "Non-Explicit Nudity of Intimate parts and Kissing": None,
    "Non-Explicit Nudity": "Non-Explicit Nudity of Intimate parts and Kissing",
    "Bare Back": "Non-Explicit Nudity",
    "Exposed Male Nipple": "Non-Explicit Nudity",
    "Partially Exposed Buttocks": "Non-Explicit Nudity",
    "Partially Exposed Female Breast": "Non-Explicit Nudity",
    "Implied Nudity": "Non-Explicit Nudity",
    "Obstructed Intimate Parts": "Non-Explicit Nudity of Intimate parts and Kissing",
    "Obstructed Female Nipple": "Obstructed Intimate Parts",
    "Obstructed Male Genitalia": "Obstructed Intimate Parts",
    "Kissing on the Lips": "Non-Explicit Nudity of Intimate parts and Kissing",
    "Swimwear or Underwear": None,
    "Female Swimwear or Underwear": "Swimwear or Underwear",
    "Male Swimwear or Underwear": "Swimwear or Underwear",
    "Violence": None,
    "Weapons": "Violence",
    "Graphic Violence": "Violence",
    "Weapon Violence": "Graphic Violence",
    "Physical Violence": "Graphic Violence",
    "Self-Harm": "Graphic Violence",
    "Blood & Gore": "Graphic Violence",
    "Explosions and Blasts": "Graphic Violence",
    "Visually Disturbing": None,
    "Death and Emaciation": "Visually Disturbing",
    "Emaciated Bodies": "Death and Emaciation",
    "Corpses": "Death and Emaciation",
    "Crashes": "Visually Disturbing",
    "Air Crash": "Crashes",
    "Drugs & Tobacco": None,
    "Products": "Drugs & Tobacco",
    "Pills": "Products",
    "Drugs & Tobacco Paraphernalia & Use": "Drugs & Tobacco",
    "Smoking": "Drugs & Tobacco Paraphernalia & Use",
    "Alcohol": None,
    "Alcohol Use": "Alcohol",
    "Drinking": "Alcohol Use",
    "Alcoholic Beverages": "Alcohol",
    "Rude Gestures": None,
    "Middle Finger": "Rude Gestures",
    "Gambling": None,
    "Hate Symbols": None,
    "Nazi Party": "Hate Symbols",
    "White Supremacy": "Hate Symbols",
    "Extremist": "Hate Symbols",
}

# Expected policy, restated independently of the implementation.
BLOCKED = {
    "Explicit": 60,
    "Explicit Nudity": 60,
    "Exposed Male Genitalia": 60,
    "Exposed Female Genitalia": 60,
    "Exposed Buttocks or Anus": 60,
    "Exposed Female Nipple": 60,
    "Explicit Sexual Activity": 60,
    "Sex Toys": 70,
    "Implied Nudity": 80,
    "Obstructed Male Genitalia": 85,
    "Violence": 80,
    "Weapons": 85,
    "Graphic Violence": 80,
    "Weapon Violence": 60,
    "Physical Violence": 90,
    "Self-Harm": 60,
    "Blood & Gore": 70,
    "Explosions and Blasts": 90,
    "Visually Disturbing": 80,
    "Death and Emaciation": 70,
    "Emaciated Bodies": 80,
    "Corpses": 60,
    "Crashes": 80,
    "Air Crash": 80,
    "Drugs & Tobacco": 80,
    "Products": 80,
    "Pills": 90,
    "Drugs & Tobacco Paraphernalia & Use": 70,
    "Smoking": 70,
    "Alcohol": 80,
    "Alcohol Use": 70,
    "Drinking": 70,
    "Alcoholic Beverages": 85,
    "Rude Gestures": 80,
    "Middle Finger": 80,
    "Gambling": 85,
    "Hate Symbols": 60,
    "Nazi Party": 60,
    "White Supremacy": 60,
    "Extremist": 60,
}
ALLOWED = set(AWS_V7_LABELS) - set(BLOCKED)


def label(name, confidence):
    return Label(name, confidence, AWS_V7_LABELS.get(name) or "")


def test_policy_covers_exact_aws_v7_taxonomy():
    assert POLICY_VERSION == "memolens-school-v1"
    assert {name: parent for name, (parent, _) in TAXONOMY.items()} == AWS_V7_LABELS
    for name, (_, rule) in TAXONOMY.items():
        assert rule.block is (name in BLOCKED)
        assert rule.min_confidence == BLOCKED.get(name)
        assert rule.min_confidence is None or 50 <= rule.min_confidence <= 100


def test_expected_school_activities_are_allowed():
    assert ALLOWED == {
        "Non-Explicit Nudity of Intimate parts and Kissing",
        "Non-Explicit Nudity",
        "Bare Back",
        "Exposed Male Nipple",
        "Partially Exposed Buttocks",
        "Partially Exposed Female Breast",
        "Obstructed Intimate Parts",
        "Obstructed Female Nipple",
        "Kissing on the Lips",
        "Swimwear or Underwear",
        "Female Swimwear or Underwear",
        "Male Swimwear or Underwear",
    }


def test_no_labels_is_benign():
    assert evaluate([]).offensive is False
    assert evaluate([]).predictions == []


@pytest.mark.parametrize("name", sorted(ALLOWED))
def test_allowed_labels_never_block_even_at_full_confidence(name):
    result = evaluate([label(name, 100.0)])
    assert result.offensive is False
    assert result.predictions == [{"class": name, "confidence": 1.0, "blocking": False}]


@pytest.mark.parametrize("name", sorted(BLOCKED))
def test_each_unsafe_label_blocks_at_and_above_its_threshold(name):
    threshold = BLOCKED[name]
    assert evaluate([label(name, threshold)]).offensive is True
    assert evaluate([label(name, 99.9)]).offensive is True
    below = evaluate([label(name, math.nextafter(threshold, 0))])
    assert below.offensive is False
    assert below.predictions[0]["blocking"] is False


def test_swim_meet_labels_together_are_benign():
    result = evaluate(
        [
            label("Swimwear or Underwear", 99.1),
            label("Female Swimwear or Underwear", 98.7),
            label("Male Swimwear or Underwear", 97.2),
            label("Non-Explicit Nudity of Intimate parts and Kissing", 91.0),
            label("Non-Explicit Nudity", 91.0),
            label("Bare Back", 88.5),
            label("Exposed Male Nipple", 90.2),
        ]
    )
    assert result.offensive is False
    assert result.blocking_count == 0
    assert len(result.predictions) == 7


def test_conflicting_parent_child_scores_fail_without_changing_thresholds():
    with pytest.raises(AmbiguousLabels):
        evaluate(
            [
                label("Violence", 88.0),
                label("Graphic Violence", 88.0),
                label("Physical Violence", 88.0),
            ]
        )
    # The child threshold remains 90; no image context is inferred from a score.
    assert evaluate([label("Physical Violence", 88.0)]).offensive is False


def test_fight_physical_violence_above_bar_blocks():
    result = evaluate(
        [
            label("Violence", 96.0),
            label("Graphic Violence", 96.0),
            label("Physical Violence", 96.0),
        ]
    )
    assert result.offensive is True
    assert [p["class"] for p in result.predictions if p["blocking"]] == [
        "Physical Violence"
    ]


def test_generic_parent_without_specific_child_uses_its_own_rule():
    assert evaluate([label("Violence", 85.0)]).offensive is True
    assert evaluate([label("Products", 85.0)]).offensive is True
    with pytest.raises(AmbiguousLabels):
        evaluate([label("Products", 95.0), label("Pills", 85.0)])
    assert evaluate([label("Products", 95.0), label("Pills", 92.0)]).offensive is True


def test_weapon_below_bar_cannot_erase_confident_violence_parent():
    labels = [label("Violence", 95.0), label("Weapons", 80.0)]
    with pytest.raises(AmbiguousLabels):
        evaluate(labels)
    labels = [label("Violence", 95.0), label("Weapons", 86.0)]
    assert evaluate(labels).offensive is True


def test_explicit_parent_still_blocks_when_specific_child_is_weaker():
    result = evaluate(
        [
            label("Explicit", 72.0),
            label("Explicit Nudity", 72.0),
            label("Exposed Female Nipple", 55.0),
        ]
    )
    assert result.offensive is True
    assert result.blocking_count == 2


def test_multiple_labels_mixed_categories_report_each_decision():
    result = evaluate(
        [
            label("Female Swimwear or Underwear", 97.0),
            label("Alcohol", 91.0),
            label("Alcoholic Beverages", 91.0),
            label("Middle Finger", 62.0),
            label("Rude Gestures", 62.0),
        ]
    )
    assert result.offensive is True
    assert result.predictions == [
        {
            "class": "Female Swimwear or Underwear",
            "confidence": 0.97,
            "blocking": False,
        },
        {"class": "Alcohol", "confidence": 0.91, "blocking": False},
        {"class": "Alcoholic Beverages", "confidence": 0.91, "blocking": True},
        {"class": "Middle Finger", "confidence": 0.62, "blocking": False},
        {"class": "Rude Gestures", "confidence": 0.62, "blocking": False},
    ]


@pytest.mark.parametrize("confidence", [50.0, 79.9, 80.0, 99.0])
@pytest.mark.parametrize("parent", ["", "Swimwear or Underwear", "Alcohol"])
def test_unknown_label_always_fails_closed(confidence, parent):
    with pytest.raises(InvalidLabels):
        evaluate([Label("Unreviewed Category", confidence, parent)])


def test_weak_pills_detection_does_not_erase_broader_drug_evidence():
    with pytest.raises(AmbiguousLabels):
        evaluate(
            [
                label("Drugs & Tobacco", 95),
                label("Products", 95),
                label("Pills", 55),
            ]
        )


def test_explicit_parent_threshold_remains_independent_of_sex_toys_threshold():
    assert evaluate([label("Sex Toys", 65)]).offensive is False
    result = evaluate([label("Explicit", 65), label("Sex Toys", 65)])
    assert result.offensive is True
    assert [p["class"] for p in result.predictions if p["blocking"]] == ["Explicit"]


@pytest.mark.parametrize("reverse", [False, True])
def test_duplicate_labels_keep_strongest_evidence_without_double_counting(reverse):
    labels = [label("Violence", 97), label("Weapons", 97), label("Weapons", 55)]
    result = evaluate(list(reversed(labels)) if reverse else labels)
    assert result.offensive is True
    assert result.blocking_count == 1
    assert len(result.predictions) == 2
    weapon = next(p for p in result.predictions if p["class"] == "Weapons")
    assert weapon == {"class": "Weapons", "confidence": 0.97, "blocking": True}


@pytest.mark.parametrize("parent", [False, None, 0, [], {}, "Violence", ""])
def test_invalid_known_label_parent_is_rejected(parent):
    with pytest.raises(InvalidLabels):
        evaluate([Label("Bare Back", 99, parent)])


@pytest.mark.parametrize(
    "labels",
    [
        [Label("Weapons", float("nan"), "Violence")],
        [Label("Weapons", float("inf"), "Violence")],
        [Label("Weapons", -1, "Violence")],
        [Label("Weapons", 100.1, "Violence")],
        [Label("Weapons", True, "Violence")],
        [Label("Weapons", "99", "Violence")],
        [Label("Weapons", None, "Violence")],
        [Label("", 99.0)],
        [Label(None, 99.0)],
        [Label("Weapons\n", 99.0)],
        [Label("<script>", 99.0)],
        [Label("x" * 101, 99.0)],
        [Label("Weapons", 99.0, 7)],
        [Label("Weapons", 99.0, "bad\x00parent")],
        [Label("Bare Back", 60.0)] * (moderation_policy.MAX_LABELS + 1),
        "not a list",
    ],
)
def test_malformed_labels_are_rejected_not_approved(labels):
    with pytest.raises(InvalidLabels):
        evaluate(labels)
