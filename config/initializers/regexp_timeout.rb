# Inventory owners may attach their own regular expressions to string fields.
# The timeout keeps a badly written expression from hanging a request.
Regexp.timeout = 1.0 if Regexp.respond_to?(:timeout=)
