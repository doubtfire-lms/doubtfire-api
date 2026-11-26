# Aggregate submission downloads can exceed the classic ZIP format's 4 GiB
# offset limit. Rubyzip leaves ZIP64 output disabled by default, which produces
# archives with wrapped local-header offsets once that limit is crossed.
Zip.write_zip64_support = true
