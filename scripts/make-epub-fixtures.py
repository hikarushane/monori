#!/usr/bin/env python3
"""Writes the deterministic EPUB fixtures used by EPUBParserTests."""
import zipfile, os
OUT = "MonoriCore/Tests/MonoriCoreTests/Fixtures"

def write(name, files, mimetype=True):
    path = os.path.join(OUT, name)
    with zipfile.ZipFile(path, "w") as z:
        if mimetype:
            z.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        for p, body in files:
            z.writestr(p, body, compress_type=zipfile.ZIP_DEFLATED)
    print("wrote", path)

CONTAINER = """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>"""

def xhtml(title, body):
    return f"""<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>{title}</title></head>
<body>{body}</body></html>"""

# --- EPUB 3 with nav TOC, three chapters, one image, one non-linear page ---
opf3 = """<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">urn:uuid:1</dc:identifier>
    <dc:title>山與海</dc:title>
    <dc:creator>林作者</dc:creator>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="c1" href="text/c1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="text/c2.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2b" href="text/c2b.xhtml" media-type="application/xhtml+xml"/>
    <item id="c3" href="text/c3.xhtml" media-type="application/xhtml+xml"/>
    <item id="img" href="img/a.png" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="cover" linear="no"/>
    <itemref idref="nav"/>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
    <itemref idref="c2b"/>
    <itemref idref="c3"/>
  </spine>
</package>"""
nav3 = """<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>目錄</title></head>
<body><nav epub:type="toc"><ol>
  <li><a href="text/c1.xhtml">第一章 山</a></li>
  <li><a href="text/c2.xhtml#start">第二章 海</a>
    <ol><li><a href="text/c2.xhtml#part2">第二章 海（續）</a></li></ol></li>
  <li><a href="text/c3.xhtml">第三章 <em>歸</em></a></li>
  <li><a href="text/missing.xhtml">不存在</a></li>
</ol></nav></body></html>"""
write("local-epub3-nav.epub", [
    ("META-INF/container.xml", CONTAINER),
    ("OEBPS/content.opf", opf3),
    ("OEBPS/nav.xhtml", nav3),
    ("OEBPS/cover.xhtml", xhtml("Cover", "<p>封面頁文字</p>")),
    ("OEBPS/text/c1.xhtml", xhtml("c1", '<p>山很高。</p><img src="../img/a.png" alt="x"/><script>alert(1)</script>')),
    ("OEBPS/text/c2.xhtml", xhtml("c2", '<p id="start">海很深。</p><p id="part2">海更深。</p>')),
    ("OEBPS/text/c2b.xhtml", xhtml("c2b", "<p>海的尾聲。</p>")),
    ("OEBPS/text/c3.xhtml", xhtml("c3", '<p>回家。<a href="https://example.com">外部連結</a></p>')),
    ("OEBPS/img/a.png", b"\x89PNG\r\n\x1a\n"),
])

# --- EPUB 2 with NCX ---
opf2 = """<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">urn:uuid:2</dc:identifier>
    <dc:title>舊書</dc:title>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="a" href="a.xhtml" media-type="application/xhtml+xml"/>
    <item id="b" href="b.xhtml" media-type="application/xhtml+xml"/>
    <item id="c" href="c.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="a"/><itemref idref="b"/><itemref idref="c"/></spine>
</package>"""
ncx = """<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <docTitle><text>舊書</text></docTitle>
  <navMap>
    <navPoint id="n1" playOrder="1"><navLabel><text>甲</text></navLabel><content src="a.xhtml"/>
      <navPoint id="n1a" playOrder="2"><navLabel><text>甲之一</text></navLabel><content src="a.xhtml#s1"/></navPoint>
    </navPoint>
    <navPoint id="n2" playOrder="3"><navLabel><text>乙</text></navLabel><content src="b.xhtml#top"/></navPoint>
  </navMap>
  <pageList><pageTarget id="p9" type="normal" value="9"><navLabel><text>9</text></navLabel><content src="c.xhtml#p9"/></pageTarget></pageList>
</ncx>"""
write("local-epub2-ncx.epub", [
    ("META-INF/container.xml", CONTAINER),
    ("OEBPS/content.opf", opf2),
    ("OEBPS/toc.ncx", ncx),
    ("OEBPS/a.xhtml", xhtml("a", "<p>甲的內容</p>")),
    ("OEBPS/b.xhtml", xhtml("b", "<p>乙的內容</p>")),
    ("OEBPS/c.xhtml", xhtml("c", "<p>乙的續篇</p>")),
])

# --- No TOC at all ---
opfn = """<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">3</dc:identifier></metadata>
  <manifest>
    <item id="a" href="a.xhtml" media-type="application/xhtml+xml"/>
    <item id="b" href="b.xhtml" media-type="application/xhtml+xml"/>
    <item id="c" href="c.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="a"/><itemref idref="b"/><itemref idref="c"/></spine>
</package>"""
write("local-epub-no-toc.epub", [
    ("META-INF/container.xml", CONTAINER),
    ("OEBPS/content.opf", opfn),
    ("OEBPS/a.xhtml", xhtml("有標題", "<p>一</p>")),
    ("OEBPS/b.xhtml", '<html><body><h2 class="t">用 H2</h2><p>二</p></body></html>'),
    ("OEBPS/c.xhtml", "<html><body><p>三</p></body></html>"),
])

# --- DRM marker ---
write("local-epub-encrypted.epub", [
    ("META-INF/container.xml", CONTAINER),
    ("META-INF/encryption.xml", "<encryption/>"),
    ("OEBPS/content.opf", opf2),
])

# --- ZIP without container.xml ---
write("local-epub-no-container.zip", [("readme.txt", "not an epub")], mimetype=False)
