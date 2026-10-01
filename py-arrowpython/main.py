import ctypes
import pyarrow as pa

from pathlib import Path

artifact_path = Path(__file__).parent.parent / "zig-out/lib/libarrowpython.so"

lib = ctypes.CDLL(artifact_path.resolve())

_get_ptr = ctypes.pythonapi.PyCapsule_GetPointer
_get_ptr.restype = ctypes.c_void_p
_get_ptr.argtypes = [ctypes.py_object, ctypes.c_char_p]

lib.array_len.restype = ctypes.c_int
lib.array_len.argtypes = [ctypes.c_void_p, ctypes.c_void_p]


def array_len(arr: pa.Array) -> int:
    schema_cap, array_cap = arr.__arrow_c_array__()
    # The capsules stay alive until this function returns,
    # so the pointers are valid for the duration of the call.
    return lib.array_len(
        _get_ptr(array_cap, b"arrow_array"),
        _get_ptr(schema_cap, b"arrow_schema"),
    )


lib.stream_len.restype = ctypes.c_int64
lib.stream_len.argtypes = [ctypes.c_void_p]


def stream_len(table: pa.Table) -> int:
    cap = table.__arrow_c_stream__()
    return lib.stream_len(_get_ptr(cap, b"arrow_array_stream"))


if __name__ == "__main__":
    print(array_len(pa.array([1.0, 2.0, 3.0])))

    print(stream_len(pa.Table.from_arrays([[1.0, 2.0], [3.0, 4.0]], names=["a", "b"])))
