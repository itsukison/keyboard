# English Autocorrect Engine

English correction uses `SymSpellSwift` with the bundled
`frequency_dictionary_en_82_765.txt` resource, plus UIKit `UITextChecker`
guesses and completions as a supplemental source in the keyboard extension.

The frequency dictionary is the SymSpell-compatible English frequency list
distributed with the MIT-licensed `gdetari/SymSpellSwift` test resources:
https://github.com/gdetari/SymSpellSwift

Runtime correction is fully local and does not require Open Access.
