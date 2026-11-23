"""Read BIFF cells for the worker's shared Excel header and column mapper."""
import json
import sys

import xlrd


def cell_text(cell, datemode):
    if cell.ctype == xlrd.XL_CELL_DATE:
        return xlrd.xldate_as_datetime(cell.value, datemode).isoformat()
    if cell.ctype == xlrd.XL_CELL_BOOLEAN:
        return "true" if cell.value else "false"
    if cell.ctype in (xlrd.XL_CELL_EMPTY, xlrd.XL_CELL_BLANK, xlrd.XL_CELL_ERROR):
        return ""
    return str(cell.value).strip()


book = xlrd.open_workbook(sys.argv[1], on_demand=True)
with open(sys.argv[2], "w", encoding="utf-8") as output:
    for name in book.sheet_names():
        for row in book.sheet_by_name(name).get_rows():
            cells = [cell_text(cell, book.datemode) for cell in row]
            if any(cells):
                output.write(json.dumps(cells, ensure_ascii=False) + "\n")
        output.write("null\n")
        book.unload_sheet(name)
