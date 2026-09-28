"""MemoLens school photo policy for AWS Rekognition moderation labels.

The policy is deliberately code, not configuration: changing what a school
photo-sharing app accepts must be a reviewed, version-controlled change.
Taxonomy: Rekognition content moderation model version 7 (three levels).
Confidences are Rekognition percentages (0-100).
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass

POLICY_VERSION = "memolens-school-v1"
# Sent as MinConfidence. This is the AWS default; every blocking threshold
# below is higher, so weaker labels are informational only.
PROVIDER_MIN_CONFIDENCE = 50.0
MAX_LABELS = 100
LABEL_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9 &,'()/.\-]{0,99}\Z")


@dataclass(frozen=True)
class Rule:
    block: bool
    min_confidence: float | None = None
    # A returned child can suppress a generic parent only without discarding
    # blocking evidence. Conflicting parent/child thresholds fail explicitly.
    generic_only: bool = False


def block(min_confidence: float, *, generic_only: bool = False) -> Rule:
    return Rule(True, min_confidence, generic_only)


ALLOW = Rule(False)

# name: (parent name or None, rule). Every v7 label is listed explicitly.
TAXONOMY: dict[str, tuple[str | None, Rule]] = {
    # Explicit sexual content: always blocked.
    "Explicit": (None, block(60)),
    "Explicit Nudity": ("Explicit", block(60)),
    "Exposed Male Genitalia": ("Explicit Nudity", block(60)),
    "Exposed Female Genitalia": ("Explicit Nudity", block(60)),
    "Exposed Buttocks or Anus": ("Explicit Nudity", block(60)),
    "Exposed Female Nipple": ("Explicit Nudity", block(60)),
    "Explicit Sexual Activity": ("Explicit", block(60)),
    "Sex Toys": ("Explicit", block(70)),
    # Non-explicit: swim meets, track, beaches, and family photos are normal.
    "Non-Explicit Nudity of Intimate parts and Kissing": (None, ALLOW),
    "Non-Explicit Nudity": (
        "Non-Explicit Nudity of Intimate parts and Kissing",
        ALLOW,
    ),
    "Bare Back": ("Non-Explicit Nudity", ALLOW),
    "Exposed Male Nipple": ("Non-Explicit Nudity", ALLOW),
    "Partially Exposed Buttocks": ("Non-Explicit Nudity", ALLOW),
    "Partially Exposed Female Breast": ("Non-Explicit Nudity", ALLOW),
    "Implied Nudity": ("Non-Explicit Nudity", block(80)),
    "Obstructed Intimate Parts": (
        "Non-Explicit Nudity of Intimate parts and Kissing",
        ALLOW,
    ),
    "Obstructed Female Nipple": ("Obstructed Intimate Parts", ALLOW),
    "Obstructed Male Genitalia": ("Obstructed Intimate Parts", block(85)),
    "Kissing on the Lips": (
        "Non-Explicit Nudity of Intimate parts and Kissing",
        ALLOW,
    ),
    "Swimwear or Underwear": (None, ALLOW),
    "Female Swimwear or Underwear": ("Swimwear or Underwear", ALLOW),
    "Male Swimwear or Underwear": ("Swimwear or Underwear", ALLOW),
    # Violence: weapons and graphic harm are blocked; contact sports get a
    # high bar before "Physical Violence" rejects a photo.
    "Violence": (None, block(80, generic_only=True)),
    "Weapons": ("Violence", block(85)),
    "Graphic Violence": ("Violence", block(80, generic_only=True)),
    "Weapon Violence": ("Graphic Violence", block(60)),
    "Physical Violence": ("Graphic Violence", block(90)),
    "Self-Harm": ("Graphic Violence", block(60)),
    "Blood & Gore": ("Graphic Violence", block(70)),
    "Explosions and Blasts": ("Graphic Violence", block(90)),
    "Visually Disturbing": (None, block(80, generic_only=True)),
    "Death and Emaciation": (
        "Visually Disturbing",
        block(70, generic_only=True),
    ),
    "Emaciated Bodies": ("Death and Emaciation", block(80)),
    "Corpses": ("Death and Emaciation", block(60)),
    "Crashes": ("Visually Disturbing", block(80, generic_only=True)),
    "Air Crash": ("Crashes", block(80)),
    # Drugs, tobacco, and alcohol are inappropriate for a school audience.
    "Drugs & Tobacco": (None, block(80, generic_only=True)),
    "Products": ("Drugs & Tobacco", block(80, generic_only=True)),
    "Pills": ("Products", block(90)),
    "Drugs & Tobacco Paraphernalia & Use": ("Drugs & Tobacco", block(70)),
    "Smoking": ("Drugs & Tobacco Paraphernalia & Use", block(70)),
    "Alcohol": (None, block(80, generic_only=True)),
    "Alcohol Use": ("Alcohol", block(70)),
    "Drinking": ("Alcohol Use", block(70)),
    "Alcoholic Beverages": ("Alcohol", block(85)),
    "Rude Gestures": (None, block(80)),
    "Middle Finger": ("Rude Gestures", block(80)),
    "Gambling": (None, block(85)),
    "Hate Symbols": (None, block(60)),
    "Nazi Party": ("Hate Symbols", block(60)),
    "White Supremacy": ("Hate Symbols", block(60)),
    "Extremist": ("Hate Symbols", block(60)),
}


class InvalidLabels(ValueError):
    """Provider output that must never be interpreted as a verdict."""


class AmbiguousLabels(InvalidLabels):
    """A blocking generic parent cannot be resolved by its returned children."""


@dataclass(frozen=True)
class Label:
    name: str
    confidence: float
    parent: str = ""


@dataclass(frozen=True)
class Evaluation:
    offensive: bool
    predictions: list[dict]
    blocking_count: int


def taxonomy_level(name: str) -> int:
    if name not in TAXONOMY:
        raise InvalidLabels
    parent = TAXONOMY[name][0]
    return 1 if parent is None else 1 + taxonomy_level(parent)


def validate_label(label: Label) -> None:
    if (
        not isinstance(label, Label)
        or not isinstance(label.name, str)
        or not LABEL_NAME.fullmatch(label.name)
        or not isinstance(label.parent, str)
        or (label.parent and not LABEL_NAME.fullmatch(label.parent))
        or isinstance(label.confidence, bool)
        or not isinstance(label.confidence, (int, float))
        or not math.isfinite(label.confidence)
        or not 0 <= label.confidence <= 100
    ):
        raise InvalidLabels
    if label.name not in TAXONOMY:
        raise InvalidLabels
    if label.parent != (TAXONOMY[label.name][0] or ""):
        raise InvalidLabels


def evaluate(labels: list[Label]) -> Evaluation:
    if not isinstance(labels, list) or len(labels) > MAX_LABELS:
        raise InvalidLabels
    for label in labels:
        validate_label(label)
    # AWS hierarchy labels are image-level evidence, not proof that a child
    # explains every concept covered by its parent. Never erase blocking parent
    # evidence merely because a weaker child exists. Keep thresholds unchanged;
    # unresolved conflicts return a recoverable failure instead of approval.
    unique = {}
    for label in labels:
        previous = unique.get(label.name)
        if previous is None or label.confidence > previous.confidence:
            unique[label.name] = label
    decisions = {}
    subtree_blocks = {}
    for label in sorted(
        unique.values(), key=lambda item: -taxonomy_level(item.name)
    ):
        rule = TAXONOMY[label.name][1]
        blocking = rule.block and label.confidence >= rule.min_confidence
        children = [item.name for item in unique.values() if item.parent == label.name]
        child_blocks = any(subtree_blocks[child] for child in children)
        subtree_blocks[label.name] = blocking or child_blocks
        if rule.generic_only and children:
            if blocking and not child_blocks:
                raise AmbiguousLabels
            blocking = False
        decisions[label.name] = blocking
    predictions = [
        {
            "class": label.name,
            # Same 0-1 scale as the historical /predict predictions.
            "confidence": round(label.confidence / 100, 4),
            "blocking": decisions[label.name],
        }
        for label in sorted(
            unique.values(), key=lambda item: (-item.confidence, item.name)
        )
    ]
    blocking_count = sum(p["blocking"] for p in predictions)
    return Evaluation(blocking_count > 0, predictions, blocking_count)
