# Generate fake sentences with minimum and maximum number of words, with an optional period in the end.
def faker_random_sentence(min_words = 0, max_words = 1, period = false)
  Faker::Lorem.words(number: Faker::Number.between(from: min_words, to: max_words)).join(' ') + (period ? '.' : '')
end
