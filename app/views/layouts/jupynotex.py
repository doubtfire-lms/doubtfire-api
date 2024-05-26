# Copyright 2020-2021  Facundo Batista
# All Rights Reserved
# Licensed under Apache 2.0

"""USAGE: jupynote.py notebook.ipynb cells

    cells is a string with which cells to include, separate groups
    with comma, ranges with dash (with defaults to start and end.
"""

import base64
import json
import re
import subprocess
import sys
import tempfile
import traceback


# basic verbatim start/end
VERBATIM_BEGIN = [r"\begin{minted}[fontsize=\footnotesize,breaklines,breakanywhere,tabsize=4]{md}"]
VERBATIM_END = [r"\end{minted}"]

# markdown start/end
MARKDOWN_BEGIN = [r"\begin{markdown}"]
MARKDOWN_END = [r"\end{markdown}"]

# highlighers for different languages (block beginning and ending)
HIGHLIGHTERS = {
    'python': ([r'\begin{minted}[fontsize=\footnotesize,breaklines,breakanywhere,tabsize=4]{python}'], [r'\end{minted}']),
    None: (VERBATIM_BEGIN, VERBATIM_END),
}

# the different formats to be used when error or all ok
FORMAT_ERROR = r"enhanced,breakable=unlimited,colback=red!5!white,colframe=red!75!"
FORMAT_OK = (
    r"enhanced,breakable=unlimited,coltitle=red!75!black, colbacktitle=black!10!white, "
    r"halign title=right, fonttitle=\sffamily\mdseries\scshape\footnotesize")


def _verbatimize(lines):
    """Wrap a series of lines around a verbatim indication."""
    result = []
    result.extend(VERBATIM_BEGIN)
    for line in lines:
        result.append(line.rstrip())
    result.extend(VERBATIM_END)
    return result


def _process_png(image_data):
    """Process a PNG: just save the received b64encoded data to a temp file."""
    _, fname = tempfile.mkstemp(suffix='.png')
    with open(fname, 'wb') as fh:
        fh.write(base64.b64decode(image_data))
    return fname


def _process_svg(image_data):
    """Process a SVG: save the data, transform to PDF, and then use that."""
    _, svg_fname = tempfile.mkstemp(suffix='.svg')
    _, pdf_fname = tempfile.mkstemp(suffix='.pdf')
    raw_svg = ''.join(image_data).encode('utf8')
    with open(svg_fname, 'wb') as fh:
        fh.write(raw_svg)

    cmd = ['inkscape', '--export-text-to-path', '--export-filename={}'.format(pdf_fname), svg_fname]
    # TODO: stderr is being captured, to avoid errors about missing window server... but we may miss others
    subprocess.run(cmd, capture_output=True)

    return pdf_fname


def _include_image_content(data):
    """Save the  and build latex to include it."""
    image_processors = [
        ('image/png', _process_png),
        ('image/svg+xml', _process_svg),
    ]
    for mimetype, function in image_processors:
        if mimetype in data:
            fname = function(data[mimetype])
            break
    else:
        raise ValueError("Image type not supported: {}".format(data.keys()))

    fname_no_backslashes = fname.replace("\\", "/")  # do not leave backslashes in Windows
    return r"\includegraphics[width=1\textwidth]{{{}}}".format(fname_no_backslashes)


class Notebook:
    """The notebook converter to latex."""

    def __init__(self, path):
        with open(path, 'rt', encoding='utf8') as fh:
            nb_data = json.load(fh)

        # get the languaje, to highlight
        lang = nb_data['metadata']['language_info']['name']
        self._highlight_delimiters = HIGHLIGHTERS.get(lang, HIGHLIGHTERS[None])

        # get all cells
        self._cells = [x for x in nb_data['cells']]

    def __len__(self):
        return len(self._cells)

    def _proc_src(self, content):
        """Process the source of a cell."""
        source = content['source']
        result = []
        if content['cell_type'] == 'code':
            begin, end = self._highlight_delimiters
            result.extend(begin)
            result.extend(line.rstrip() for line in source)
            result.extend(end)
        elif content['cell_type'] == 'markdown':
            result.extend(MARKDOWN_BEGIN)
            result.extend(line.replace('```markdown', '```md').strip() for line in source)
            result.extend(MARKDOWN_END)
        elif content['cell_type'] == 'raw':
            result.extend(VERBATIM_BEGIN)
            result.extend(textwrap.fill(line[:1000] + ' [The rest of this line has been truncated by the system to improve readability.] ' * (len(line) > 1000), width=90, subsequent_indent='    ') for line in source)
            result.extend(VERBATIM_END)
        else:
            raise ValueError(
                "Cell type not supported when processing source: {!r}".format(
                    content['cell_type']))

        return '\n'.join(result) + '\n'

    def _proc_out(self, content):
        """Process the output of a cell."""
        outputs = content.get('outputs')
        if not outputs:
            return

        result = []
        for item in outputs:
            output_type = item['output_type']
            if output_type == 'execute_result':
                data = item['data']
                if 'text/latex' in data:
                    result.extend(data["text/latex"])
                elif 'image/png' in data or 'image/svg+xml' in data:
                    result.append(_include_image_content(data))
                else:
                    result.extend(_verbatimize(data["text/plain"]))
            elif output_type == 'stream':
                more_content = processor.process_plain_text(item["text"])
                if len(more_content) > 120:
                    more_content = more_content[:100] + ["..."] + more_content[-20:]
            elif output_type == 'error':
                raw_traceback = item['traceback']
                tback_lines = []
                for raw_line in raw_traceback:
                    internal_lines = raw_line.split('\n')
                    for line in internal_lines:
                        line = re.sub(r"\x1b\[\d.*?m", "", line)  # sanitize
                        if set(line) == {'-'}:
                            # ignore separator, as our graphical box already has one
                            continue
                        tback_lines.append(line)
                result.extend(_verbatimize(tback_lines))
            else:
                raise ValueError("Output type not supported in item {!r}".format(item))

        return '\n'.join(result) + '\n'

    def get(self, cell_idx):
        """Return the content from a specific cell in the notebook.

        The content is already splitted in source and output, and converted to latex.
        """
        content = self._cells[cell_idx - 1]
        source = self._proc_src(content)
        output = self._proc_out(content)
        return source, output, content['cell_type'] == 'markdown'

def _parse_cells(spec, maxlen):
    """Convert the cells spec to a range of ints."""
    if not spec:
        raise ValueError("Empty cells spec not allowed")
    if set(spec) - set('0123456789-,'):
        raise ValueError(
            "Found forbidden characters in cells definition (allowed digits, '-' and ',')")

    cells = set()
    groups = spec.split(',')
    for group in groups:
        if '-' in group:
            cfrom, cto = group.split('-')
            cfrom = 1 if cfrom == '' else int(cfrom)
            cto = maxlen if cto == '' else int(cto)
            if cfrom >= cto:
                raise ValueError(
                    "Range 'from' need to be smaller than 'to' (got {!r})".format(group))
            cells.update(range(cfrom, cto + 1))
        else:
            cells.add(int(group))
    cells = sorted(cells)

    if any(x < 1 for x in cells):
        raise ValueError("Cells need to be >=1")
    if maxlen < cells[-1]:
        raise ValueError(
            "Notebook loaded of len {}, smaller than requested cells: {}".format(maxlen, cells))

    return cells


def main(notebook_path, cells_spec):
    """Main entry point."""
    nb = Notebook(notebook_path)
    cells = _parse_cells(cells_spec, len(nb))

    for cell in cells:
        try:
            src, out, md = nb.get(cell)
        except Exception:
            title = "ERROR when parsing cell {}".format(cell)
            print(r"\begin{{tcolorbox}}[{}, title={{{}}}]".format(FORMAT_ERROR, title))
            tb = traceback.format_exc()
            print('\n'.join(_verbatimize(tb.split('\n'))))
            print(r"\end{tcolorbox}")
            continue

        if not md:
          print(r"\begin{{tcolorbox}}[{}, title=Cell {{{:02d}}}]".format(FORMAT_OK, cell))

        print(src)

        if out:
            if not md:
              print(r"\tcblower")
            print(out)
        if not md:
          print(r"\end{tcolorbox}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        exit()

    main(*sys.argv[1:3])
