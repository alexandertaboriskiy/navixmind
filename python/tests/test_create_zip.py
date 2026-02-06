"""
Comprehensive tests for the create_zip function in documents.py.

Tests cover:
- Happy path: single file, multiple files, different compression modes
- Error handling: empty file list, missing files, disk errors, invalid compression
- Edge cases: duplicate basenames, files with no extension, deeply nested output path
- Output validation: file count, size, compression mode in result
- Archive contents verification
"""

import os
import tempfile
import zipfile
import unittest
from unittest.mock import patch, MagicMock

from navixmind.tools.documents import create_zip
from navixmind.bridge import ToolError


class TestCreateZipHappyPath(unittest.TestCase):
    """Tests for successful ZIP creation."""

    def setUp(self):
        """Create temp directory and files for testing."""
        self.temp_dir = tempfile.mkdtemp()
        self.file1 = os.path.join(self.temp_dir, "file1.txt")
        self.file2 = os.path.join(self.temp_dir, "file2.txt")
        self.file3 = os.path.join(self.temp_dir, "image.png")

        with open(self.file1, 'w') as f:
            f.write("Hello from file 1")
        with open(self.file2, 'w') as f:
            f.write("Hello from file 2")
        with open(self.file3, 'wb') as f:
            f.write(b'\x89PNG\r\n\x1a\n' + b'\x00' * 100)

        self.output_path = os.path.join(self.temp_dir, "output.zip")

    def tearDown(self):
        """Clean up temp files."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_single_file(self):
        """Create ZIP with a single file."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file1],
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["output_path"], self.output_path)
        self.assertEqual(result["file_count"], 1)
        self.assertGreater(result["size_bytes"], 0)
        self.assertTrue(os.path.isfile(self.output_path))

        # Verify archive contents
        with zipfile.ZipFile(self.output_path, 'r') as zf:
            names = zf.namelist()
            self.assertEqual(len(names), 1)
            self.assertEqual(names[0], "file1.txt")
            self.assertEqual(zf.read("file1.txt").decode(), "Hello from file 1")

    def test_multiple_files(self):
        """Create ZIP with multiple files."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file1, self.file2, self.file3],
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["file_count"], 3)

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            names = zf.namelist()
            self.assertEqual(len(names), 3)
            self.assertIn("file1.txt", names)
            self.assertIn("file2.txt", names)
            self.assertIn("image.png", names)

    def test_deflated_compression(self):
        """ZIP with deflated compression (default)."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file1],
            compression="deflated",
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["compression"], "deflated")

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            info = zf.getinfo("file1.txt")
            self.assertEqual(info.compress_type, zipfile.ZIP_DEFLATED)

    def test_stored_compression(self):
        """ZIP with stored (no compression) mode."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file1],
            compression="stored",
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["compression"], "stored")

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            info = zf.getinfo("file1.txt")
            self.assertEqual(info.compress_type, zipfile.ZIP_STORED)

    def test_default_compression_is_deflated(self):
        """Default compression should be deflated."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file1],
        )

        self.assertEqual(result["compression"], "deflated")

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            info = zf.getinfo("file1.txt")
            self.assertEqual(info.compress_type, zipfile.ZIP_DEFLATED)

    def test_size_mb_in_result(self):
        """Result should include size_mb field."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file1],
        )

        self.assertIn("size_mb", result)
        self.assertIsInstance(result["size_mb"], float)
        self.assertGreaterEqual(result["size_mb"], 0)

    def test_output_directory_created(self):
        """Output directory should be created if it doesn't exist."""
        nested_output = os.path.join(self.temp_dir, "sub", "dir", "archive.zip")

        result = create_zip(
            output_path=nested_output,
            file_paths=[self.file1],
        )

        self.assertTrue(result["success"])
        self.assertTrue(os.path.isfile(nested_output))

    def test_binary_file_content_preserved(self):
        """Binary file content should be preserved in ZIP."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.file3],
        )

        self.assertTrue(result["success"])

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            content = zf.read("image.png")
            self.assertTrue(content.startswith(b'\x89PNG'))


class TestCreateZipDuplicateNames(unittest.TestCase):
    """Tests for duplicate basename handling."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.output_path = os.path.join(self.temp_dir, "output.zip")

        # Create files with same basename in different directories
        self.sub1 = os.path.join(self.temp_dir, "dir1")
        self.sub2 = os.path.join(self.temp_dir, "dir2")
        os.makedirs(self.sub1)
        os.makedirs(self.sub2)

        self.dup1 = os.path.join(self.sub1, "data.txt")
        self.dup2 = os.path.join(self.sub2, "data.txt")

        with open(self.dup1, 'w') as f:
            f.write("Content from dir1")
        with open(self.dup2, 'w') as f:
            f.write("Content from dir2")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_duplicate_basenames_renamed(self):
        """Files with same basename should get unique archive names."""
        result = create_zip(
            output_path=self.output_path,
            file_paths=[self.dup1, self.dup2],
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["file_count"], 2)

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            names = zf.namelist()
            self.assertEqual(len(names), 2)
            self.assertIn("data.txt", names)
            self.assertIn("data_1.txt", names)

    def test_duplicate_basenames_content_correct(self):
        """Each duplicate file should have correct content."""
        create_zip(
            output_path=self.output_path,
            file_paths=[self.dup1, self.dup2],
        )

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            self.assertEqual(zf.read("data.txt").decode(), "Content from dir1")
            self.assertEqual(zf.read("data_1.txt").decode(), "Content from dir2")

    def test_three_duplicate_basenames(self):
        """Three files with same basename get sequential suffixes."""
        sub3 = os.path.join(self.temp_dir, "dir3")
        os.makedirs(sub3)
        dup3 = os.path.join(sub3, "data.txt")
        with open(dup3, 'w') as f:
            f.write("Content from dir3")

        create_zip(
            output_path=self.output_path,
            file_paths=[self.dup1, self.dup2, dup3],
        )

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            names = zf.namelist()
            self.assertEqual(len(names), 3)
            self.assertIn("data.txt", names)
            self.assertIn("data_1.txt", names)
            self.assertIn("data_2.txt", names)

    def test_duplicate_basename_no_extension(self):
        """Files with same basename and no extension are handled."""
        noext1 = os.path.join(self.sub1, "README")
        noext2 = os.path.join(self.sub2, "README")
        with open(noext1, 'w') as f:
            f.write("readme 1")
        with open(noext2, 'w') as f:
            f.write("readme 2")

        create_zip(
            output_path=self.output_path,
            file_paths=[noext1, noext2],
        )

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            names = zf.namelist()
            self.assertEqual(len(names), 2)
            self.assertIn("README", names)
            self.assertIn("README_1", names)


class TestCreateZipErrors(unittest.TestCase):
    """Tests for error handling."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.output_path = os.path.join(self.temp_dir, "output.zip")
        self.valid_file = os.path.join(self.temp_dir, "valid.txt")
        with open(self.valid_file, 'w') as f:
            f.write("valid content")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_empty_file_paths_raises_error(self):
        """Empty file_paths should raise ToolError."""
        with self.assertRaises(ToolError) as ctx:
            create_zip(
                output_path=self.output_path,
                file_paths=[],
            )

        self.assertIn("at least one file", str(ctx.exception))

    def test_missing_file_raises_error(self):
        """Non-existent file should raise ToolError."""
        with self.assertRaises(ToolError) as ctx:
            create_zip(
                output_path=self.output_path,
                file_paths=["/nonexistent/file.txt"],
            )

        self.assertIn("File not found", str(ctx.exception))
        self.assertIn("/nonexistent/file.txt", str(ctx.exception))

    def test_missing_file_among_valid_files(self):
        """If any file is missing, error should occur before archive creation."""
        with self.assertRaises(ToolError) as ctx:
            create_zip(
                output_path=self.output_path,
                file_paths=[self.valid_file, "/nonexistent/other.txt"],
            )

        self.assertIn("File not found", str(ctx.exception))
        # Archive should NOT have been created
        self.assertFalse(os.path.exists(self.output_path))

    def test_invalid_compression_raises_error(self):
        """Invalid compression method should raise ToolError."""
        with self.assertRaises(ToolError) as ctx:
            create_zip(
                output_path=self.output_path,
                file_paths=[self.valid_file],
                compression="bzip2",
            )

        self.assertIn("Unsupported compression", str(ctx.exception))
        self.assertIn("bzip2", str(ctx.exception))

    def test_invalid_compression_lzma(self):
        """LZMA compression should raise ToolError (not supported)."""
        with self.assertRaises(ToolError) as ctx:
            create_zip(
                output_path=self.output_path,
                file_paths=[self.valid_file],
                compression="lzma",
            )

        self.assertIn("Unsupported compression", str(ctx.exception))

    def test_generic_exception_wrapped_in_tool_error(self):
        """Unexpected exceptions should be wrapped in ToolError."""
        with patch('navixmind.tools.documents.zipfile.ZipFile', side_effect=OSError("Disk full")):
            with self.assertRaises(ToolError) as ctx:
                create_zip(
                    output_path=self.output_path,
                    file_paths=[self.valid_file],
                )

            self.assertIn("Failed to create ZIP", str(ctx.exception))
            self.assertIn("Disk full", str(ctx.exception))

    def test_tool_error_not_double_wrapped(self):
        """ToolError should be re-raised directly, not wrapped again."""
        with self.assertRaises(ToolError) as ctx:
            create_zip(
                output_path=self.output_path,
                file_paths=[],
            )

        # Should be the direct "at least one file" error, not "Failed to create ZIP"
        self.assertIn("at least one file", str(ctx.exception))
        self.assertNotIn("Failed to create ZIP", str(ctx.exception))


class TestCreateZipEdgeCases(unittest.TestCase):
    """Tests for edge cases."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.output_path = os.path.join(self.temp_dir, "output.zip")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_empty_file(self):
        """ZIP should handle empty (0-byte) files."""
        empty_file = os.path.join(self.temp_dir, "empty.txt")
        with open(empty_file, 'w') as f:
            pass  # 0 bytes

        result = create_zip(
            output_path=self.output_path,
            file_paths=[empty_file],
        )

        self.assertTrue(result["success"])

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            self.assertEqual(zf.read("empty.txt"), b"")

    def test_large_file(self):
        """ZIP should handle large files."""
        large_file = os.path.join(self.temp_dir, "large.bin")
        with open(large_file, 'wb') as f:
            f.write(b'x' * (1024 * 1024))  # 1 MB of x's

        result = create_zip(
            output_path=self.output_path,
            file_paths=[large_file],
        )

        self.assertTrue(result["success"])
        # Deflated compression should make this smaller
        self.assertLess(result["size_bytes"], 1024 * 1024)

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            content = zf.read("large.bin")
            self.assertEqual(len(content), 1024 * 1024)

    def test_file_with_spaces_in_name(self):
        """Files with spaces in name should work."""
        spaced_file = os.path.join(self.temp_dir, "my document.txt")
        with open(spaced_file, 'w') as f:
            f.write("content with spaces")

        result = create_zip(
            output_path=self.output_path,
            file_paths=[spaced_file],
        )

        self.assertTrue(result["success"])

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            self.assertIn("my document.txt", zf.namelist())

    def test_file_with_special_characters(self):
        """Files with special characters should work."""
        special_file = os.path.join(self.temp_dir, "report-2024_v2.1.txt")
        with open(special_file, 'w') as f:
            f.write("special chars")

        result = create_zip(
            output_path=self.output_path,
            file_paths=[special_file],
        )

        self.assertTrue(result["success"])

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            self.assertIn("report-2024_v2.1.txt", zf.namelist())

    def test_output_path_without_directory(self):
        """Output path with no directory component (just filename)."""
        # Use a path in current directory
        bare_output = os.path.join(self.temp_dir, "archive.zip")
        test_file = os.path.join(self.temp_dir, "test.txt")
        with open(test_file, 'w') as f:
            f.write("test")

        result = create_zip(
            output_path=bare_output,
            file_paths=[test_file],
        )

        self.assertTrue(result["success"])

    def test_same_file_twice(self):
        """Adding the same file twice should create two entries."""
        test_file = os.path.join(self.temp_dir, "data.txt")
        with open(test_file, 'w') as f:
            f.write("data")

        result = create_zip(
            output_path=self.output_path,
            file_paths=[test_file, test_file],
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["file_count"], 2)

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            names = zf.namelist()
            self.assertEqual(len(names), 2)
            self.assertIn("data.txt", names)
            self.assertIn("data_1.txt", names)

    def test_mixed_text_and_binary_files(self):
        """ZIP with both text and binary files."""
        text_file = os.path.join(self.temp_dir, "notes.txt")
        bin_file = os.path.join(self.temp_dir, "image.jpg")

        with open(text_file, 'w') as f:
            f.write("Some notes")
        with open(bin_file, 'wb') as f:
            f.write(b'\xff\xd8\xff\xe0' + b'\x00' * 50)

        result = create_zip(
            output_path=self.output_path,
            file_paths=[text_file, bin_file],
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["file_count"], 2)

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            self.assertEqual(zf.read("notes.txt").decode(), "Some notes")
            self.assertTrue(zf.read("image.jpg").startswith(b'\xff\xd8\xff\xe0'))

    def test_overwrite_existing_zip(self):
        """Creating ZIP at existing path should overwrite."""
        test_file = os.path.join(self.temp_dir, "data.txt")
        with open(test_file, 'w') as f:
            f.write("version 1")

        # Create first archive
        create_zip(output_path=self.output_path, file_paths=[test_file])

        # Overwrite with new content
        with open(test_file, 'w') as f:
            f.write("version 2")

        result = create_zip(output_path=self.output_path, file_paths=[test_file])

        self.assertTrue(result["success"])

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            self.assertEqual(zf.read("data.txt").decode(), "version 2")

    def test_unicode_content_preserved(self):
        """Unicode content in files should be preserved."""
        unicode_file = os.path.join(self.temp_dir, "unicode.txt")
        with open(unicode_file, 'w', encoding='utf-8') as f:
            f.write("Hello\u2603\u2764\u00e9\u00f1")

        result = create_zip(
            output_path=self.output_path,
            file_paths=[unicode_file],
        )

        self.assertTrue(result["success"])

        with zipfile.ZipFile(self.output_path, 'r') as zf:
            content = zf.read("unicode.txt").decode('utf-8')
            self.assertIn("\u2603", content)
            self.assertIn("\u2764", content)


class TestCreateZipToolIntegration(unittest.TestCase):
    """Tests for create_zip integration with the tools framework."""

    def test_schema_registered(self):
        """create_zip should be in TOOLS_SCHEMA."""
        from navixmind.tools import TOOLS_SCHEMA

        tool_names = [t["name"] for t in TOOLS_SCHEMA]
        self.assertIn("create_zip", tool_names)

    def test_schema_required_fields(self):
        """Schema should require output_path and file_paths."""
        from navixmind.tools import TOOLS_SCHEMA

        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "create_zip")
        required = schema["input_schema"]["required"]
        self.assertIn("output_path", required)
        self.assertIn("file_paths", required)

    def test_schema_compression_enum(self):
        """Schema compression should be enum with deflated and stored."""
        from navixmind.tools import TOOLS_SCHEMA

        schema = next(t for t in TOOLS_SCHEMA if t["name"] == "create_zip")
        compression_prop = schema["input_schema"]["properties"]["compression"]
        self.assertEqual(compression_prop["enum"], ["deflated", "stored"])

    def test_in_tool_map(self):
        """create_zip should be callable via execute_tool."""
        from navixmind.tools import execute_tool

        temp_dir = tempfile.mkdtemp()
        try:
            test_file = os.path.join(temp_dir, "test.txt")
            output_path = os.path.join(temp_dir, "out.zip")
            with open(test_file, 'w') as f:
                f.write("test")

            result = execute_tool(
                "create_zip",
                {"output_path": output_path, "file_paths": [test_file]},
                context={},
            )

            self.assertTrue(result["success"])
        finally:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

    def test_file_paths_resolved_from_file_map(self):
        """file_paths should be resolved via _file_map context."""
        from navixmind.tools import execute_tool

        temp_dir = tempfile.mkdtemp()
        try:
            real_path = os.path.join(temp_dir, "data.csv")
            output_path = os.path.join(temp_dir, "archive.zip")
            with open(real_path, 'w') as f:
                f.write("a,b,c")

            result = execute_tool(
                "create_zip",
                {"output_path": output_path, "file_paths": ["data.csv"]},
                context={"_file_map": {"data.csv": real_path}},
            )

            self.assertTrue(result["success"])

            with zipfile.ZipFile(output_path, 'r') as zf:
                self.assertEqual(zf.read("data.csv").decode(), "a,b,c")
        finally:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)

    def test_output_path_resolved_from_output_dir(self):
        """Relative output_path should be resolved via output_dir context."""
        from navixmind.tools import execute_tool

        temp_dir = tempfile.mkdtemp()
        try:
            test_file = os.path.join(temp_dir, "test.txt")
            with open(test_file, 'w') as f:
                f.write("test")

            output_dir = os.path.join(temp_dir, "output")

            result = execute_tool(
                "create_zip",
                {"output_path": "archive.zip", "file_paths": [test_file]},
                context={"output_dir": output_dir},
            )

            self.assertTrue(result["success"])
            self.assertTrue(result["output_path"].startswith(output_dir))
            self.assertTrue(os.path.isfile(result["output_path"]))
        finally:
            import shutil
            shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
