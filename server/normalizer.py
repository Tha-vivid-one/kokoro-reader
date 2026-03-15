"""Text normalization for TTS — converts numbers, symbols, and abbreviations to spoken form."""

import re


def normalize(text: str) -> str:
    """Normalize text for natural TTS output."""
    text = _expand_urls(text)
    text = _expand_currency(text)
    text = _expand_percentages(text)
    text = _expand_ordinals(text)
    text = _expand_numbers(text)
    text = _expand_abbreviations(text)
    text = _expand_symbols(text)
    text = _clean_whitespace(text)
    return text


def _expand_currency(text: str) -> str:
    # $1,234.56 → "1,234 dollars and 56 cents" (cents handled by number expansion later)
    def replace_dollars(m):
        sign = m.group(1) or ""
        whole = m.group(2).replace(",", "")
        cents_raw = m.group(3)
        result = sign + _number_to_words(int(whole))
        if cents_raw:
            cents = int(cents_raw[1:])  # strip leading dot
            if cents > 0:
                result += " dollars and " + _number_to_words(cents) + " cents"
                return result
        result += " dollar" if whole == "1" else " dollars"
        return result

    # Currency ranges: $10-$50 → "ten to fifty dollars"
    def replace_dollar_range(m):
        lo = int(m.group(1).replace(",", ""))
        hi = int(m.group(2).replace(",", ""))
        return _number_to_words(lo) + " to " + _number_to_words(hi) + " dollars"

    text = re.sub(r"\$(\d[\d,]*)\s*[-–]\s*\$(\d[\d,]*)", replace_dollar_range, text)

    text = re.sub(r"(-)?\$(\d[\d,]*)(\.\d{2})?(?!\d)", replace_dollars, text)

    # €, £ variants
    def replace_euro(m):
        n = int(m.group(1).replace(",", ""))
        return _number_to_words(n) + (" euro" if n == 1 else " euros")

    def replace_pound(m):
        n = int(m.group(1).replace(",", ""))
        return _number_to_words(n) + (" pound" if n == 1 else " pounds")

    text = re.sub(r"€(\d[\d,]*)", replace_euro, text)
    text = re.sub(r"£(\d[\d,]*)", replace_pound, text)
    return text


def _expand_percentages(text: str) -> str:
    def replace_pct(m):
        num = m.group(1)
        if "." in num:
            return num + " percent"
        return _number_to_words(int(num.replace(",", ""))) + " percent"

    return re.sub(r"(\d[\d,.]*)\s*%", replace_pct, text)


def _expand_ordinals(text: str) -> str:
    def replace_ordinal(m):
        n = int(m.group(1))
        return _ordinal_to_words(n)

    return re.sub(r"\b(\d+)(st|nd|rd|th)\b", replace_ordinal, text)


def _expand_numbers(text: str) -> str:
    # Decimals: 3.14 → "3 point 1 4"
    def replace_decimal(m):
        whole = m.group(1).replace(",", "")
        frac = m.group(2)
        result = _number_to_words(int(whole)) + " point "
        result += " ".join(_number_to_words(int(d)) for d in frac)
        return result

    text = re.sub(r"\b(\d[\d,]*)\.(\d+)\b", replace_decimal, text)

    # Ranges: 10-20 → "10 to 20"
    text = re.sub(
        r"\b(\d[\d,]*)\s*[-–]\s*(\d[\d,]*)\b",
        lambda m: _number_to_words(int(m.group(1).replace(",", "")))
        + " to "
        + _number_to_words(int(m.group(2).replace(",", ""))),
        text,
    )

    # Standalone numbers with commas: 83,000 → "eighty-three thousand"
    def replace_number(m):
        raw = m.group(0).replace(",", "")
        return _number_to_words(int(raw))

    text = re.sub(r"\b\d{1,3}(?:,\d{3})+\b", replace_number, text)

    # Plain large numbers without commas: 83000
    def replace_plain(m):
        n = int(m.group(0))
        if n > 999:
            return _number_to_words(n)
        return m.group(0)  # Leave small numbers for model to handle

    text = re.sub(r"\b\d{4,}\b", replace_plain, text)

    return text


def _expand_abbreviations(text: str) -> str:
    abbrevs = {
        r"\bDr\.": "Doctor",
        r"\bMr\.": "Mister",
        r"\bMrs\.": "Missus",
        r"\bMs\.": "Ms",
        r"\bJr\.": "Junior",
        r"\bSr\.": "Senior",
        r"\bSt\.": "Saint",
        r"\bvs\.": "versus",
        r"\betc\.": "etcetera",
        r"\be\.g\.": "for example",
        r"\bi\.e\.": "that is",
        r"\bw/": "with",
        r"\bw/o\b": "without",
    }
    for pattern, replacement in abbrevs.items():
        text = re.sub(pattern, replacement, text)
    return text


def _expand_symbols(text: str) -> str:
    text = text.replace("&", " and ")
    text = text.replace("+", " plus ")
    text = text.replace("=", " equals ")
    text = re.sub(r"\s*@\s*", " at ", text)
    # Slash between words: "and/or" → "and or"
    text = re.sub(r"(\w)/(\w)", r"\1 \2", text)
    return text


def _expand_urls(text: str) -> str:
    # Simplify URLs to just domain
    def replace_url(m):
        url = m.group(0)
        # Extract domain
        domain = re.sub(r"https?://", "", url)
        domain = domain.split("/")[0]
        return domain

    text = re.sub(r"https?://[^\s,)]+", replace_url, text)
    return text


def _clean_whitespace(text: str) -> str:
    text = re.sub(r"  +", " ", text)
    return text.strip()


# --- Number to words engine ---

_ones = [
    "", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
    "seventeen", "eighteen", "nineteen",
]

_tens = [
    "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
]

_scales = [
    (10**12, "trillion"),
    (10**9, "billion"),
    (10**6, "million"),
    (10**3, "thousand"),
    (10**2, "hundred"),
]


def _number_to_words(n: int) -> str:
    if n < 0:
        return "negative " + _number_to_words(-n)
    if n == 0:
        return "zero"

    parts = []
    for value, name in _scales:
        if n >= value:
            count = n // value
            parts.append(_number_to_words(count) + " " + name)
            n %= value

    if n >= 20:
        part = _tens[n // 10]
        if n % 10:
            part += "-" + _ones[n % 10]
        parts.append(part)
    elif n > 0:
        parts.append(_ones[n])

    return " ".join(parts)


def _ordinal_to_words(n: int) -> str:
    word = _number_to_words(n)
    # Handle special endings
    if word.endswith("one"):
        return word[:-3] + "first"
    elif word.endswith("two"):
        return word[:-3] + "second"
    elif word.endswith("three"):
        return word[:-5] + "third"
    elif word.endswith("five"):
        return word[:-4] + "fifth"
    elif word.endswith("eight"):
        return word + "h"
    elif word.endswith("nine"):
        return word[:-1] + "th"
    elif word.endswith("twelve"):
        return word[:-2] + "fth"
    elif word.endswith("ty"):
        return word[:-2] + "tieth"
    else:
        return word + "th"
