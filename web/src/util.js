export function prettyPrintPages(inp) {
  inp *= 4096.0;

  if (inp < 1024) {
    return inp + "";
  }

  inp /= 1024.0;
  if (inp < 1024) {
    return inp.toFixed(1) + "KiB";
  }

  inp /= 1024.0;
  if (inp < 1024) {
    return inp.toFixed(1) + "MiB";
  }

  inp /= 1024.0;
  if (inp < 1024) {
    return inp.toFixed(1) + "GiB";
  }

  inp /= 1024.0;
  if (inp < 1024) {
    return inp.toFixed(1) + "TiB";
  }
}
