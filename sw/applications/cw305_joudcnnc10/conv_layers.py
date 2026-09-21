# id, name, strides, pads, kernel_shape, dilations, group
CONV_LAYERS = [
    {"id": 0, "name": "conv1", "in_shape": (1,1,28,28), "out_shape": (1,16,28,28), "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (16, 1, 3, 3), "dilations": (1, 1), "group": 1},
    {"id": 1, "name": "conv2", "in_shape": (1,16,14,14), "out_shape": (1,32,14,14), "strides": (1, 1), "pads": (1, 1, 1, 1), "kernel_shape": (32, 16, 3, 3), "dilations": (1, 1), "group": 1},
]

CONV_BY_ID = {layer["id"]: layer for layer in CONV_LAYERS}


def _fmt(value):
    return " ".join(str(v) for v in value) if isinstance(value, tuple) else str(value)


def print_table():
    cols = ["id", "name", "strides", "pads", "kernel_shape", "dilations", "group"]
    rows = [[_fmt(layer[c]) for c in cols] for layer in CONV_LAYERS]
    widths = [max(len(c), *(len(r[i]) for r in rows)) for i, c in enumerate(cols)]
    line = "  ".join(c.ljust(w) for c, w in zip(cols, widths))
    print(line)
    print("-" * len(line))
    for r in rows:
        print("  ".join(v.ljust(w) for v, w in zip(r, widths)))


if __name__ == "__main__":
    print_table()
