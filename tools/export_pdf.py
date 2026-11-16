"""
export_pdf.py - LibreOffice macro: open the .docx report, update the table of
contents (page numbers), save the .docx and export a PDF.
It runs INSIDE LibreOffice (see scripts/export_pdf.sh), driven by env vars
REPORT_DOCX and REPORT_PDF.
"""
import os
import uno
from com.sun.star.beans import PropertyValue


def _p(n, v):
    p = PropertyValue()
    p.Name, p.Value = n, v
    return p


def export_report(*args):
    src, dst = os.environ["REPORT_DOCX"], os.environ["REPORT_PDF"]
    desktop = XSCRIPTCONTEXT.getDesktop()  # noqa: F821 (provided by LibreOffice)
    doc = desktop.loadComponentFromURL(uno.systemPathToFileUrl(src), "_blank", 0, (_p("Hidden", True),))
    for _ in range(2):                     # twice: the TOC itself can shift pages
        idx = doc.getDocumentIndexes()
        for i in range(idx.getCount()):
            idx.getByIndex(i).update()
        doc.refresh()
    doc.storeToURL(uno.systemPathToFileUrl(dst), (_p("FilterName", "writer_pdf_Export"),))
    doc.storeToURL(uno.systemPathToFileUrl(src), (_p("FilterName", "MS Word 2007 XML"),))
    doc.close(True)
    desktop.terminate()


g_exportedScripts = (export_report,)
