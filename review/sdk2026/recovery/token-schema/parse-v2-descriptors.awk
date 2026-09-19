# Read `od -An -v -tu1` output. Emit descriptor metadata only after validation.
# Payload bytes are counted and discarded; never interpolated into output/errors.
BEGIN { state = "version"; headers = 0; payload = 0; total = 0; bad = 0 }
{
  for (field = 1; field <= NF; field++) {
    byte = $field + 0; total++
    if ($field !~ /^[0-9]+$/ || byte < 0 || byte > 255) { bad = 1; exit 1 }
    if (state == "version") {
      if (byte != 2) { bad = 1; exit 1 }
      state = "header"; h = 0; id = 0
    } else if (payload > 0) {
      payload--
    } else {
      h++
      if (h <= 4) id = id * 256 + byte
      else if (h == 5) counter = byte
      else if (h == 6) size = byte
      else {
        count = byte
        if (counter > 1 || seen[id]++) { bad = 1; exit 1 }
        rows[++headers] = sprintf("0x%08x,%d,%d,%d", id, counter, size, count)
        payload = size * count; h = 0; id = 0
      }
    }
  }
}
END {
  if (bad || state == "version" || h != 0 || payload != 0) {
    print "Invalid or truncated v2 token stream; no descriptors emitted" > "/dev/stderr"
    exit 1
  }
  print "id,counter,size,count"
  for (i = 1; i <= headers; i++) print rows[i]
}
