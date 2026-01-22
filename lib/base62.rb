module Base62
  ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.freeze
  BASE = ALPHABET.length

  def self.encode(number)
    return ALPHABET[0] if number == 0

    value = number
    encoded = +''
    while value > 0
      encoded.prepend(ALPHABET[value % BASE])
      value /= BASE
    end
    encoded
  end
end
