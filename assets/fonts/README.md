# Roboto (bundled for PDF export)

`roboto-regular.ttf` and `roboto-bold.ttf` are copies of the Roboto files that
ship with the Flutter SDK (`bin/cache/artifacts/material_fonts/`), included so
`lib/core/export/export_pdf.dart` can embed a real Unicode font.

Why: the `pdf` package's built-in Helvetica is WinAnsi-only. It silently drops
anything outside Latin-1 — the rupee sign (₹), Devanagari, curly quotes — so a
title or note containing them vanished from the printed export.

Roboto is licensed under the Apache License, Version 2.0:

    Copyright 2011 Google Inc. All Rights Reserved.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

Do not swap these for a font from `C:\Windows\Fonts` — Microsoft's system fonts
cannot be redistributed with an app.

## Known gap: other scripts

Roboto (the copy Flutter ships) covers Latin, Greek, Cyrillic and symbols such
as ₹ and em dashes — everything the exporter previously dropped. It does **not**
cover Devanagari or CJK: a Hindi title in a transaction still renders as
nothing. Closing that needs a second font registered as `fontFallback` in
`lib/core/export/export_pdf.dart`, e.g. Noto Sans Devanagari (OFL):

    pw.ThemeData.withFont(base: regular, bold: bold, fontFallback: [devanagari])

