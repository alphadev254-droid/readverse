"""
Text normalization for TTS.
Basic normalization to improve speech quality.
"""

import re


def normalize_text(text: str) -> str:
    """
    Normalize text for better TTS output.
    
    Args:
        text: Raw input text
        
    Returns:
        Normalized text
    """
    # Remove excessive whitespace
    text = re.sub(r'\s+', ' ', text)
    
    # Remove pipe characters (often used as separators)
    text = text.replace('|', ',')
    
    # Normalize quotes
    text = text.replace('"', '"').replace('"', '"')
    text = text.replace(''', "'").replace(''', "'")
    
    # Remove URLs (TTS reads them poorly)
    text = re.sub(r'https?://\S+', 'URL omitted', text)
    
    # Remove email addresses
    text = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'email address', text)
    
    # Normalize ellipsis
    text = text.replace('...', '.')
    text = re.sub(r'\.{2,}', '.', text)
    
    # Ensure sentences end with punctuation
    text = re.sub(r'([a-z])\s+([A-Z])', r'\1. \2', text)
    
    # Remove multiple punctuation
    text = re.sub(r'([.!?]){2,}', r'\1', text)
    
    # Strip and return
    return text.strip()
