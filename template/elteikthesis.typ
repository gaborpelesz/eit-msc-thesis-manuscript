// =============================================================================
// Typst port of elteikthesis v2.4
//   https://github.com/mcserep/elteikthesis, tag v2.4, commit 4f0162d9b7
//   original (c) 2013-2024 Máté Cserép, Bálint Bognár, MIT licence
//   (see LICENSE in the repository root; this port is distributed under the
//   same licence).
//
// Requires Typst 0.15 (tested with 0.15.1). No Typst Universe packages.
//
// Deviation from the class: the page margins follow the faculty's formal
// thesis requirements (A4, 12pt, justified, 1.5 line spacing; margins inside,
// outside, top and bottom 2.5 cm), which override the class's 35 mm inner
// margin. See `_margin-inside`.
//
// Mapping of the LaTeX class to this module
//   \documentclass options   -> parameters of `elteikthesis` (parspace,
//                               noindent, nohyp, twoside, draft, final)
//   \documentlang{...}       -> `lang: "en" | "hu"`
//   \maketitle               -> `make-title` (called by `elteikthesis`)
//   \tableofcontents         -> `table-of-contents` (called by `elteikthesis`)
//   \chapter, \section, ...  -> `=`, `==`, `===` headings
//   \chapter*                -> `#heading(numbering: none)[...]`
//   \appendix                -> `#show: appendix`
//   \printbibliography       -> `#bibliography("file.bib")` (styled here)
//   \listoffigures, ...      -> `list-of-figures()`, `list-of-tables()`,
//                               `list-of-algorithms()`, `list-of-codes()`
//   \printnomenclature       -> `nomenclature(...)` + `print-nomenclature()`
//   \listoftodos, \todo      -> `list-of-todos()`, `todo[...]`
//   definition, theorem, remark, note, proof environments -> functions
//   lstlisting / minted      -> raw blocks (```lang ... ```) inside `figure`
//   algorithm + algorithmic  -> `algorithm(...)` + `algorithmic(...)`
//   \includepdf              -> `include-pdf(...)`
// =============================================================================

#let elteikthesis-version = "2.4"   // version of the ported LaTeX class
#let port-version = "2.4.0"          // version of this Typst port

// -----------------------------------------------------------------------------
// Translations (\documentlang). The `*-title` keys are the headings babel
// prints on the list pages; the plain keys are the class's own labels, used
// in the table of contents (the LaTeX class shows exactly this mismatch in
// Hungarian: "Ábrák jegyzéke" on the page, "Ábrajegyzék" in the contents).
// -----------------------------------------------------------------------------
#let translations = (
  hu: (
    author: "Szerző",
    supervisor: "Témavezető",
    int-supervisor: "Belső témavezető",
    ext-supervisor: "Külső témavezető",
    definition: "Definíció",
    theorem: "Tétel",
    remark: "Emlékeztető",
    note: "Megjegyzés",
    proof: "Bizonyítás",
    code: "forráskód",
    algorithm: "algoritmus",
    figure: "ábra",
    table: "táblázat",
    equation: "egyenlet",
    step: "lépés",
    chapter: "fejezet",
    appendix: "függelék",
    section: "szakasz",
    contents: "Tartalomjegyzék",
    bibliography: "Irodalomjegyzék",
    list-of-algorithms: "Algoritmusjegyzék",
    list-of-figures: "Ábrajegyzék",
    list-of-tables: "Táblázatjegyzék",
    list-of-codes: "Forráskódjegyzék",
    list-of-symbols: "Jelölésjegyzék",
    todo: "Teendők listája",
    acknowledgements: "Köszönetnyilvánítás",
    list-of-figures-title: "Ábrák jegyzéke",
    list-of-tables-title: "Táblázatok jegyzéke",
  ),
  en: (
    author: "Author",
    supervisor: "Supervisor",
    int-supervisor: "Internal supervisor",
    ext-supervisor: "External supervisor",
    definition: "Definition",
    theorem: "Theorem",
    remark: "Remark",
    note: "Note",
    proof: "Proof",
    code: "Code",
    algorithm: "Algorithm",
    figure: "Figure",
    table: "Table",
    equation: "Equation",
    step: "Step",
    chapter: "Chapter",
    appendix: "Appendix",
    section: "Section",
    contents: "Contents",
    bibliography: "Bibliography",
    list-of-algorithms: "List of Algorithms",
    list-of-figures: "List of Figures",
    list-of-tables: "List of Tables",
    list-of-codes: "List of Codes",
    list-of-symbols: "List of Symbols",
    todo: "Todo list",
    acknowledgements: "Acknowledgements",
    list-of-figures-title: "List of Figures",
    list-of-tables-title: "List of Tables",
  ),
)

// Translation lookup; must be called inside `context`.
#let _tr(key) = translations.at(text.lang, default: translations.en).at(key)
// Translation as content, usable anywhere (e.g. `#heading[#tr("acknowledgements")]`).
#let tr(key) = context _tr(key)
#let _is-hu() = text.lang == "hu"

// -----------------------------------------------------------------------------
// Dimensions (measured from / derived like the LaTeX class)
// -----------------------------------------------------------------------------
#let _size = (
  tiny: 6pt, scriptsize: 8pt, footnotesize: 10pt, small: 10.95pt,
  normal: 12pt, large: 14.4pt, Large: 17.28pt, LARGE: 20.74pt,
  huge: 24.88pt, Huge: 24.88pt,
)
// Fonts: Latin Modern (template/fonts, GUST Font License), optical sizes as
// LaTeX's OT1 Computer Modern picks them; New Computer Modern as fallback
// (missing glyphs, or when template/fonts is not on the font path).
#let _fallback = ("New Computer Modern",)
#let _rm12 = ("Latin Modern Roman 12", .._fallback)   // cmr12, cmbx12 (also > 12pt), cmti12, cmsl12
#let _rm10 = ("Latin Modern Roman", .._fallback)      // cmr10 (\small, \footnotesize), cmbxti10
#let _rm6 = ("Latin Modern Roman 6", .._fallback)     // cmr6 (\tiny)
#let _sc = ("Latin Modern Roman Caps", .._fallback)   // cmcsc10
#let _tt10 = ("Latin Modern Mono", "DejaVu Sans Mono") // cmtt10
#let _tt12 = ("Latin Modern Mono 12", "Latin Modern Mono", "DejaVu Sans Mono") // cmtt12

// \setstretch{1.427465}: 14.5pt baselineskip of 12pt report -> ~20.62pt
#let _stretch = 1.427465
#let _baseline = 20.62pt
// Every line is set with a 0.7em/0.3em strut (top-edge/bottom-edge), so the
// distance of two baselines is 1em + leading.
#let _leading = _baseline - 12pt           // stretched body text
#let _single-leading = 14.5pt - 12pt       // floats, captions (setspace)
#let _parindent = 17.62pt                  // 1.5em of cmr12
#let _topskip-shift = 15pt - 0.7 * 12pt    // first baseline 15pt below text top
// Formal requirements: 2.5 cm on every side (the class has a 35 mm inner margin).
#let _margin-inside = 25mm
#let _margin-outside = 25mm
#let _textwidth = 210mm - _margin-inside - _margin-outside
#let _em = 11.74pt                         // em (quad) of cmr12 at 12pt
#let _float-heading-extra = 4pt            // measured: [H] float followed by a heading

// -----------------------------------------------------------------------------
// Internal state
// -----------------------------------------------------------------------------
#let _appendix = state("elteikthesis-appendix", false)
#let _final = state("elteikthesis-final", false)
#let _twoside = state("elteikthesis-twoside", false)
#let _indent = state("elteikthesis-indent", _parindent)
#let _in-outline = state("elteikthesis-in-outline", false)

// Labels identifying the special level-1 headings produced by this module.
// value: (toc text key, page style)  style: "list" = tocloft title,
// "star" = \chapter*
#let _special = (
  "elte-toc": (toc: "contents", style: "list"),
  "elte-lof": (toc: "list-of-figures", style: "list"),
  "elte-lot": (toc: "list-of-tables", style: "list"),
  // algorithm.sty and listings print their lists with \chapter*
  "elte-loa": (toc: "list-of-algorithms", style: "star"),
  "elte-loc": (toc: "list-of-codes", style: "star"),
  "elte-bib": (toc: "bibliography", style: "star"),
  "elte-los": (toc: "list-of-symbols", style: "star"),
  "elte-todos": (toc: "todo", style: "star"),
)
#let _special-of(h) = {
  if h.has("label") { _special.at(str(h.label), default: none) } else { none }
}

// -----------------------------------------------------------------------------
// Numbering helpers (all "at a location", so they are correct wherever used)
// -----------------------------------------------------------------------------
#let _chapter-str(n, app) = if app { numbering("A", n) } else { str(n) }

// "2", "2.1", "A.1", ... (no trailing dot)
#let _heading-num-at(loc) = {
  let nums = counter(heading).at(loc)
  let app = _appendix.at(loc)
  (_chapter-str(nums.first(), app), ..nums.slice(1).map(str)).join(".")
}

#let _chapter-at(loc) = _chapter-str(counter(heading).at(loc).first(), _appendix.at(loc))

// Kinds numbered within chapters (chngcntr / report defaults).
#let _per-chapter-kinds = (image, table, raw)

// Number of a referable element as a plain string, or none.
#let _number-of(el) = {
  let loc = el.location()
  if el.func() == heading {
    if el.numbering == none { return none }
    return _heading-num-at(loc)
  }
  if el.func() == math.equation {
    if el.numbering == none { return none }
    return _chapter-at(loc) + "." + str(counter(math.equation).at(loc).first())
  }
  if el.func() == figure {
    if el.numbering == none { return none }
    let n = counter(figure.where(kind: el.kind)).at(loc).first()
    if el.kind in _per-chapter-kinds { return _chapter-at(loc) + "." + str(n) }
    if el.kind == "subfigure" { return numbering("a", n) }
    return str(n)
  }
  none
}

// Numbering functions (displayed at the element's own location).
#let _heading-numbering(..nums) = context {
  let n = nums.pos()
  let s = (_chapter-str(n.first(), _appendix.get()), ..n.slice(1).map(str)).join(".")
  if _is-hu() { s + "." } else { s }
}
#let _per-chapter-numbering(n) = context {
  _chapter-str(counter(heading).get().first(), _appendix.get()) + "." + str(n)
}
#let _equation-numbering(n) = context {
  "(" + _chapter-str(counter(heading).get().first(), _appendix.get()) + "." + str(n) + ")"
}

// -----------------------------------------------------------------------------
// Small helpers
// -----------------------------------------------------------------------------
// \slshape: Computer Modern Slanted has no counterpart in New Computer Modern;
// emulate it by skewing the upright face (cmsl slant = 1/6).
// \slshape: LM Roman Slanted 12 (cmsl12)
#let _slanted(body) = text(font: _rm12, style: "oblique", body)

// Plain text of simple content (for PDF metadata).
#let _plain-text-raw(it) = {
  if it == none { return "" }
  if type(it) == str { return it }
  if type(it) != content { return str(it) }
  if it.has("text") { return it.text }
  if it.has("children") { return it.children.map(_plain-text-raw).join("") }
  if it.has("body") { return _plain-text-raw(it.body) }
  if it.func() == [ ].func() or it.func() == linebreak { return " " }
  ""
}
#let _plain-text(it) = _plain-text-raw(it).replace(regex("\s+"), " ").trim()

// \bigskip, \medskip, \smallskip
#let bigskip = v(12pt)
#let medskip = v(6pt)
#let smallskip = v(3pt)

// `\hline\hline` inside a table: an empty 2pt high row (\doublerulesep).
#let double-rule(columns) = range(columns).map(_ => table.cell(inset: 0pt, box(height: 2pt)))

// \caption[short]{long}: the short form is shown in the lists of figures etc.
#let flex-caption(long, short) = context if _in-outline.get() { short } else { long }

// -----------------------------------------------------------------------------
// Todo notes (todonotes: left margin, 30mm wide, orange!10, small text)
// -----------------------------------------------------------------------------
#let _todo-fill = rgb(255, 128, 0).lighten(90%)
#let _todo-stroke = rgb(255, 128, 0)

#let todo(body, inline: false) = {
  let note(width) = block(
    width: width, fill: _todo-fill, stroke: 0.5pt + _todo-stroke, radius: 2pt,
    inset: 3pt, breakable: false,
    {
      set text(font: _rm10, size: _size.small, style: "normal", weight: "regular",
        top-edge: 0.7em, bottom-edge: -0.3em)
      set par(leading: 0.2em, justify: false, first-line-indent: 0pt,
        hanging-indent: 0pt, spacing: 0.2em)
      set align(left)
      body
    },
  )
  context {
    if _final.get() { return }
    if inline {
      block(above: 6pt, below: 6pt, note(100%))
    } else {
      let pos = here().position()
      let page-w = 210mm
      // \reversemarginpar: notes go to the inner margin (left in oneside).
      let left-side = not _twoside.get() or calc.odd(pos.page)
      let inner = _margin-inside
      let sep = 10pt   // \marginparsep
      // \marginparwidth is 30mm in the class; narrowed so notes fit in the
      // 2.5 cm margin with a 3 mm gap to the paper edge.
      let w = inner - sep - 3mm
      let x = if left-side { inner - sep - w } else { page-w - inner + sep }
      let anchor = if left-side { x + w } else { x }
      let raise = 0.9em.to-absolute()
      // Stack below earlier margin notes on this page instead of overlapping
      // them (todonotes moves colliding notes down as well).
      let bottom = none
      for m in query(selector(<elte-todo>).before(here())) {
        let p = m.location().position()
        if m.value.inline or p.page != pos.page { continue }
        let side = not _twoside.get() or calc.odd(p.page)
        if side != left-side { continue }
        let top = p.y - raise
        if bottom != none { top = calc.max(top, bottom + 2pt) }
        bottom = top + measure(m.value.note).height
      }
      let top = pos.y - raise
      if bottom != none { top = calc.max(top, bottom + 2pt) }
      let dy = top - pos.y
      box(width: 0pt, {
        if dy > -raise + 0.5pt {
          // displaced note: one straight connector from the text position to
          // the middle of the note's edge
          let mid = dy + measure(note(w)).height / 2
          place(line(start: (0pt, 2pt), end: (anchor - pos.x, mid),
            stroke: 0.5pt + _todo-stroke))
        } else {
          place(dx: anchor - pos.x, dy: 2pt,
            line(length: pos.x - anchor, stroke: 0.5pt + _todo-stroke))
        }
        place(dx: x - pos.x, dy: dy, note(w))
      })
    }
  }
  context if not _final.get() [#metadata((body: body, inline: inline, note: note(30mm)))<elte-todo>]
}

// \listoftodos[\todolabel]
#let list-of-todos() = context {
  if _final.get() { return }   // todonotes obeyFinal
  [#heading(level: 1, numbering: none, outlined: false)[#tr("todo")] <elte-todos>]
  {
    for t in query(<elte-todo>) {
      let p = counter(page).at(t.location()).first()
      block(above: _leading, below: _leading,
        link(t.location(), grid(columns: (1fr, 1.55 * _em),
          [#t.value.body #box(width: 1fr, repeat(gap: 5.97pt, justify: false)[.])],
          align(right, str(p)))))
    }
  }
}

// -----------------------------------------------------------------------------
// Theorem-like environments (amsthm)
//   definition: definition style, numbered   ("Definition 1." / "1. Definíció.")
//   theorem:    plain style, numbered, italic ("Theorem 1."    / "1. Tétel.")
//   remark, note: remark style, unnumbered (italic head)
//   proof:      italic head, QED box
// -----------------------------------------------------------------------------
#let _thm-skip = _leading + 10.2pt

#let _thm-block(head, body, italic: false, skip: _thm-skip) = context {
  let ind = _indent.get()
  block(above: skip, below: skip, width: 100%, breakable: true, {
    set par(first-line-indent: (amount: ind, all: false))
    set align(left)
    if italic { set text(style: "italic"); [#head #body] } else [#head #body]
  })
}

#let definition(body) = figure(kind: "definition", supplement: tr("definition"),
  numbering: "1", outlined: false, body)
#let theorem(body) = figure(kind: "theorem", supplement: tr("theorem"),
  numbering: "1", outlined: false, body)
// remark style: half \topsep above and below
#let remark(body) = _thm-block(emph[#tr("remark").], body, skip: _leading + 4.4pt)
#let note(body) = _thm-block(emph[#tr("note").], body, skip: _leading + 4.4pt)

#let qed-symbol = box(width: 0.6em, height: 0.675em, stroke: 0.4pt, baseline: 0pt)
#let proof(body) = _thm-block(emph[#tr("proof").],
  [#body#h(1fr)#qed-symbol], skip: _leading + 6pt)

#let _show-theorem(it) = context {
  let n = it.counter.display(it.numbering)
  let head = if _is-hu() [#n. #it.supplement.] else [#it.supplement #n.]
  let ind = _indent.get()
  block(above: _thm-skip, below: _thm-skip, width: 100%, breakable: true, {
    set par(first-line-indent: (amount: ind, all: false))
    set align(left)
    if it.kind == "theorem" {
      [#strong(head) #text(style: "italic", it.body)]
    } else {
      [#strong(head) #it.body]
    }
  })
}

// -----------------------------------------------------------------------------
// Algorithms (algorithm float, ruled; algpseudocode-like line list)
// -----------------------------------------------------------------------------
// #algorithm(caption: [...])[ body ] <alg:label>
#let algorithm(body, caption: none) = figure(kind: "algorithm",
  supplement: tr("algorithm"), numbering: "1", caption: caption, body)

// #algorithmic(line, line, ...)   each line is one of
//   content                                  (indent level 0)
//   (level, content)                         (array)
//   (level, content, comment)                comment: content or none
//   (level, content, comment, <label>)       label: referable as a step
// `numbered: false` hides the line numbers (\begin{algorithmic}[0]).
#let algorithmic(..lines, numbered: true) = {
  counter(figure.where(kind: "algline")).update(0)
  let rows = ()
  let i = 0
  for l in lines.pos() {
    i += 1
    let (level, body, comment, lbl) = if type(l) == array {
      (l.at(0), l.at(1), l.at(2, default: none), l.at(3, default: none))
    } else { (0, l, none, none) }
    let num = figure(kind: "algline", supplement: tr("step"), numbering: "1",
      outlined: false, text(font: _rm10, size: _size.footnotesize)[#i:])
    let num = if lbl != none [#num#lbl] else { num }
    rows.push(if numbered { align(right, num) } else { [] })
    rows.push(pad(left: level * 1.5 * _em, {
      body
      if comment != none [#h(1fr)$triangle.small.r$ #comment]
    }))
  }
  set par(first-line-indent: 0pt, hanging-indent: 0pt, justify: false)
  grid(columns: (13.4pt, 1fr), column-gutter: 5.4pt, row-gutter: _single-leading,
    ..rows)
}

// -----------------------------------------------------------------------------
// longtable: a table that may break across pages; it is not a float, so it
// keeps the stretched line spacing (setspace) and LaTeX's left alignment.
//   #longtable(table(..., table.header(...), ...), caption: [...]) <tab:label>
// -----------------------------------------------------------------------------
#let longtable(body, caption: none) = {
  show figure: set block(breakable: true)
  figure(kind: table, caption: caption, {
    set par(leading: _leading, spacing: _leading)
    set table(inset: (x: 6pt, top: 0.7 * 14.5pt * _stretch - 0.7 * 12pt,
      bottom: 0.3 * 14.5pt * _stretch - 0.3 * 12pt))
    set align(left)
    body
  })
}

// -----------------------------------------------------------------------------
// Subfigures (subcaption): #subfigure(image(...), caption: [...])
// -----------------------------------------------------------------------------
#let subfigure(body, caption: none) = figure(kind: "subfigure", supplement: none,
  numbering: "(a)", outlined: false, caption: caption, body)

// -----------------------------------------------------------------------------
// Multi-line display equations with one number per line (amsmath align).
//   #align-equations(
//     ($A$, $= (pi r^2)/2$),                 numbered
//     ($$,  $= 1/2 pi r^2$, <eq:label>),     numbered, labelled
//     ($f(u)$, $= ...$, false),              \nonumber
//   )
// Each line becomes its own numbered `math.equation`; the left- and right-hand
// sides are set in boxes of common width so the `=` signs line up.
// -----------------------------------------------------------------------------
#let align-equations(..rows) = block(above: 16.2pt, below: 20.7pt, width: 100%, context {
  let atom = box(width: 0pt)   // invisible ordinary atom: keeps the relation spacing
  let rows = rows.pos().map(r => (
    lhs: r.at(0).body,
    rhs: r.at(1).body,
    opt: r.at(2, default: true),
  ))
  let w(x) = measure(math.equation(math.display(x))).width
  let rows = rows.map(r => r + (wl: w(r.lhs), wr: w([#atom#r.rhs])))
  let wl = calc.max(..rows.map(r => r.wl))
  let wr = calc.max(..rows.map(r => r.wr))
  // the display skips are the outer block's above/below (outside this
  // context), so they collapse with neighbouring spacing like a single
  // equation's; between lines \jot-like 3pt
  show math.equation: set block(above: 3.7pt, below: 3.7pt)
  for r in rows {
    let numbered = r.opt != false
    let eq = math.equation(block: true, numbering: if numbered { _equation-numbering } else { none },
      math.display([#h(wl - r.wl)#r.lhs#atom#r.rhs#h(wr - r.wr)]))
    if type(r.opt) == label [#eq#r.opt] else { eq }
  }
})

// -----------------------------------------------------------------------------
// Nomenclature (nomencl, options intoc, noprefix, refpage)
// -----------------------------------------------------------------------------
#let nomenclature(symbol, description) = [#metadata((symbol: symbol, description: description))<elte-nomencl>]

#let print-nomenclature() = {
  [#heading(level: 1, numbering: none)[#tr("list-of-symbols")] <elte-los>]
  context {
    for n in query(<elte-nomencl>) {
      let p = counter(page).at(n.location()).first()
      block(above: _leading, below: _leading, grid(columns: (1cm, 1fr), column-gutter: 1em,
        align(right, n.value.symbol), [#n.value.description, #link(n.location(), str(p))]))
    }
  }
}

// -----------------------------------------------------------------------------
// \includepdf: full pages without header/footer.
//   #include-pdf(read("topicdeclaration.pdf", encoding: none), pages: (1,))
// -----------------------------------------------------------------------------
#let include-pdf(source, pages: (1,)) = {
  for p in pages {
    page(margin: 0pt, header: none, footer: none,
      image(source, format: "pdf", page: p, width: 100%, height: 100%, fit: "contain"))
  }
}

// -----------------------------------------------------------------------------
// Title page (\maketitle)
// -----------------------------------------------------------------------------
#let make-title(
  title: [], author: [], degree: [], supervisor: [], affiliation: [],
  ext-supervisor: none, ext-affiliation: none,
  university: [], faculty: [], department: [], city: [], year: [], logo: none,
) = context {
  // All lines are laid out baseline to baseline (zero-height lines), so the
  // vertical distances below are the LaTeX baseline distances.
  set text(top-edge: "baseline", bottom-edge: "baseline")
  // Over-long lines run into the margin as in LaTeX; break them by hand
  // with `\` (e.g. department, affiliation), lines then follow at 20.7pt.
  set par(first-line-indent: 0pt, justify: false, spacing: 0pt, leading: 14.5pt * _stretch)
  let line(size: _size.normal, it) = block(text(size: size, it))
  // cmcsc10 (lowercase letters are small capitals in this font; the
  // smallcaps() only matters for the fallback font)
  let sc(size, it) = text(font: _sc, size: size, smallcaps(all: false, it))

  // University / faculty / department, next to the logo (a tabular whose
  // first column is the logo moved left by 1cm).
  let col1 = 6pt + (0.25 * _textwidth - 1cm) + 6pt
  let rows = (
    sc(_size.Large, university),
    sc(_size.Large, faculty),
    sc(_size.large, department),
  )
  let w2 = calc.max(..rows.map(r => measure(block(r)).width))
  let total = col1 + w2 + 12pt
  let offset = calc.max(0pt, (_textwidth - total) / 2)
  v(108.8pt - 70.87pt - _topskip-shift)
  block(width: 100%, {
    if logo != none {
      place(dx: offset + 6pt - 1cm, dy: -16.3pt,
        box(width: 0.25 * _textwidth, height: 0.25 * _textwidth, logo))
    }
    pad(left: offset + col1 + 6pt, block(width: w2, {
      set align(center)
      set par(leading: 18pt * _stretch)
      line(rows.at(0))
      v(39.96pt)
      line(rows.at(1))
      v(41.4pt)
      line(rows.at(2))
    }))
  })
  {
    set text(bottom-edge: "bounds")
    v(164.56pt)
    align(center, block({
      set par(leading: 25pt * _stretch, justify: false)
      text(size: _size.LARGE, weight: "bold", title)
    }))
  }
  let label(it) = text(size: _size.large, style: "italic", it)
  let big(it) = text(size: _size.large, it)
  let r = 20.7pt   // tabular row pitch (stretched strut)
  // tabular { l c l } with a 4cm middle column; like LaTeX, an over-wide
  // tabular starts at the left margin and runs into the right margin.
  let cols(a, b) = {
    let w1 = calc.max(..a.map(x => measure(x).width))
    let w3 = calc.max(..b.map(x => measure(x).width))
    let w = w1 + 4cm + w3 + 3 * 12pt
    pad(left: calc.max(0pt, (_textwidth - w) / 2) + 6pt, block(width: w,
      grid(columns: (w1, 4cm, w3), column-gutter: 12pt, row-gutter: r, align: left,
        ..a.zip(b).map(((x, y)) => (x, [], y)).flatten())))
  }
  if ext-supervisor != none or ext-affiliation != none {
    v(157.08pt - 28.35pt)
    align(center, {
      block(label[#_tr("author"):]); v(r)
      block(big(author)); v(r)
      block(degree)
    })
    v(2cm + r)
    cols(
      (label[#_tr("int-supervisor"):], big(supervisor), affiliation),
      (label[#_tr("ext-supervisor"):], big(ext-supervisor), ext-affiliation),
    )
  } else {
    v(157.08pt)
    cols(
      (label[#_tr("supervisor"):], big(supervisor), affiliation),
      (label[#_tr("author"):], big(author), degree),
    )
  }
  v(1fr)
  align(center, text(style: "italic")[#city, #year])
  v(771.02pt - 758.07pt)
  [#metadata("title") <elte-frontmatter-end>]
}

// -----------------------------------------------------------------------------
// Table of contents and lists (tocloft defaults of the report class)
// -----------------------------------------------------------------------------
#let _toc-rmarg = 2.55 * _em
#let _toc-pnum = 1.55 * _em

#let _leaders = box(width: 1fr, repeat(gap: 5.97pt, justify: false)[.])

#let _toc-line(indent, numwidth, number, title, page, leaders: true, bold: false) = {
  set par(first-line-indent: 0pt, hanging-indent: 0pt, justify: false, leading: _leading)
  set text(weight: if bold { "bold" } else { "regular" }, hyphenate: false)
  grid(columns: (indent, numwidth, 1fr, _toc-pnum),
    [], number,
    pad(right: if leaders { 0pt } else { _toc-rmarg - _toc-pnum },
      [#title#if leaders [~#_leaders]]),
    align(right + bottom, page))
}

#let _outline-entry(el) = {
  let loc = el.location()
  // LaTeX records the page of \caption (for a longtable: its last page)
  let page-loc = if el.func() == figure and el.caption != none {
    let caps = query(figure.caption.where(kind: el.kind).after(loc))
    if caps.len() > 0 { caps.first().location() } else { loc }
  } else { loc }
  let page = str(counter(page).at(page-loc).first())
  let hu = _is-hu()
  let dot(s) = if s == none { none } else if hu { s + "." } else { s }
  let entry = if el.func() == heading {
    let num = _number-of(el)
    let sp = _special-of(el)
    let title = if sp != none { _tr(sp.toc) } else { el.body }
    if el.level == 1 {
      block(above: _leading + 1 * _em, below: _leading,
        link(loc, _toc-line(0pt, if num == none { 0pt } else { 1.5 * _em }, dot(num), title, page,
          leaders: false, bold: true)))
    } else {
      let (ind, w) = if el.level == 2 { (1.5 * _em, 2.3 * _em) } else if el.level == 3 {
        (3.8 * _em, 3.2 * _em)
      } else { (7.0 * _em, 4.1 * _em) }
      block(above: _leading, below: _leading, link(loc, _toc-line(ind, w, dot(num), title, page)))
    }
  } else {
    // figure, table, code, algorithm entries
    let num = _number-of(el)
    let title = if el.caption != none { el.caption.body } else { [] }
    block(above: _leading, below: _leading,
      link(loc, _toc-line(1.5 * _em, 2.3 * _em, dot(num), title, page)))
  }
  entry
}
#let _show-outline-entry(it) = context _outline-entry(it.element)

#let _list-heading(lbl, key) = [#heading(level: 1, numbering: none, outlined: lbl != <elte-toc>,
  bookmarked: lbl != <elte-toc>)[#tr(key)] #lbl]

#let _list-of(lbl, key, target) = {
  _list-heading(lbl, key)
  _in-outline.update(true)
  outline(title: none, target: target)
  _in-outline.update(false)
}

#let table-of-contents() = {
  _list-heading(<elte-toc>, "contents")
  counter(page).update(1)   // \pagenumbering{gobble} restarts the counter
  // \l@chapter's penalty: a chapter line never ends a page when sections
  // follow it. The chapter line and its first section entry are set as one
  // unbreakable block (`sticky` did not hold inside the template's flow).
  context {
    let hs = query(heading.where(outlined: true)).filter(h => h.level <= 3)
    let i = 0
    while i < hs.len() {
      let h = hs.at(i)
      let nxt = hs.at(i + 1, default: none)
      if h.level == 1 and nxt != none and nxt.level > 1 {
        block(above: _leading + 1 * _em, below: _leading, breakable: false,
          _outline-entry(h) + _outline-entry(nxt))
        i += 2
      } else {
        _outline-entry(h)
        i += 1
      }
    }
  }
  [#metadata("toc") <elte-frontmatter-end>]
}
#let list-of-figures() = _list-of(<elte-lof>, "list-of-figures-title", figure.where(kind: image))
#let list-of-tables() = _list-of(<elte-lot>, "list-of-tables-title", figure.where(kind: table))
#let list-of-codes() = _list-of(<elte-loc>, "list-of-codes", figure.where(kind: raw))
#let list-of-algorithms() = _list-of(<elte-loa>, "list-of-algorithms", figure.where(kind: "algorithm"))

// -----------------------------------------------------------------------------
// Appendix (\appendix): chapters are lettered A, B, ...
// -----------------------------------------------------------------------------
#let appendix(body) = {
  _appendix.update(true)
  counter(heading).update(0)
  body
}

// -----------------------------------------------------------------------------
// Running header (fancyhdr) and footer
// -----------------------------------------------------------------------------
// The mark a level-1 heading sets (\chaptermark / \@mkboth), or none.
#let _mark-of(h) = {
  let sp = _special-of(h)
  if sp != none { return upper(h.body) }
  if h.numbering == none { return none }
  [#_heading-num-at(h.location()). #h.body]
}

#let _is-blank-page(p) = {
  // a page inserted by pagebreak(to: "odd"): after the end marker of the
  // previous chapter and before the next chapter start
  let next = query(heading.where(level: 1)).filter(h => h.location().page() >= p)
  if next.len() == 0 { return false }
  let nxt = next.first()
  if nxt.location().page() == p { return false }
  let ends = query(<elte-chapter-end>).filter(m => m.location().page() < nxt.location().page())
  if ends.len() == 0 { return false }
  ends.last().location().page() < p
}

#let _header() = context {
  let p = here().page()
  let fm = query(<elte-frontmatter-end>)
  if fm.len() > 0 and p <= fm.first().location().page() { return none }   // title page
  if query(heading.where(level: 1)).any(h => h.location().page() == p) { return none }
  if _twoside.get() and _is-blank-page(p) { return none }
  let before = query(heading.where(level: 1).before(here()))
  let chapter-mark = none
  let chapter-loc = none
  for h in before.rev() {
    let m = _mark-of(h)
    if m != none { chapter-mark = m; chapter-loc = h.location(); break }
  }
  if chapter-mark == none and before.len() == 0 { return none }
  let mark = chapter-mark
  if _twoside.get() and calc.odd(p) {
    // \rightmark: first section mark on this page, else the last one before
    let secs = query(heading.where(level: 2)).filter(h => h.numbering != none and (chapter-loc == none or h.location().page() > chapter-loc.page() or (h.location().page() == chapter-loc.page() and h.location().position().y > chapter-loc.position().y)))
    let on-page = secs.filter(h => h.location().page() == p)
    let prev = secs.filter(h => h.location().page() < p)
    let s = if on-page.len() > 0 { on-page.first() } else if prev.len() > 0 { prev.last() } else { none }
    mark = if s == none { [] } else [#_heading-num-at(s.location()). #s.body]
  }
  set text(top-edge: 0.7em, bottom-edge: -0.3em)
  set par(first-line-indent: 0pt)
  set block(spacing: 0pt)
  block(width: 100%, {
    align(center, _slanted(if mark == none { [] } else { mark }))
    v(1.08pt, weak: false)
    line(length: 100%, stroke: 1pt)
  })
}

#let _footer() = context {
  let p = here().page()
  let fm = query(<elte-frontmatter-end>)
  if fm.len() > 0 and p <= fm.last().location().page() { return none }    // \pagenumbering{gobble}
  if _twoside.get() and _is-blank-page(p) { return none }
  set text(top-edge: 0.7em, bottom-edge: -0.3em)
  align(center, str(counter(page).get().first()))
}

// -----------------------------------------------------------------------------
// The document class
// -----------------------------------------------------------------------------
#let elteikthesis(
  // metadata
  title: [],
  author: [],
  degree: [],
  supervisor: [],
  affiliation: [],
  ext-supervisor: none,
  ext-affiliation: none,
  university: [],
  faculty: [],
  department: [],
  city: [],
  year: [],
  logo: none,
  // \documentlang
  lang: "en",
  // class options
  parspace: false,   // vertical space between paragraphs
  noindent: false,   // no first-line indentation
  nohyp: false,      // no hyphenation
  twoside: false,    // double sided format (openright)
  draft: false,      // frames instead of images
  final: false,      // hide todo notes
  revision: none,    // build stamp (e.g. a commit SHA) in the bottom margin; hidden when final
  // front matter produced by this function
  titlepage: true,
  declaration: none, // e.g. include-pdf(read("topicdeclaration.pdf", encoding: none))
  toc: true,
  body,
) = {
  set document(title: _plain-text(title), author: _plain-text(author))

  // ---- page ----------------------------------------------------------------
  set page(
    paper: "a4",
    margin: if twoside {
      (inside: _margin-inside, outside: _margin-outside, top: 25mm + _topskip-shift, bottom: 25mm)
    } else {
      (left: _margin-inside, right: _margin-outside, top: 25mm + _topskip-shift, bottom: 25mm)
    },
    header: _header(),
    header-ascent: 25mm + _topskip-shift - 46.44pt,
    footer: _footer(),
    footer-descent: 40pt - 0.7 * 12pt,
    foreground: if revision != none and not final {
      place(bottom + right, dx: -10mm, dy: -8mm,
        text(font: _rm12, size: 8pt, fill: luma(130))[#revision])
    },
    numbering: none,
  )
  _final.update(final)
  _twoside.update(twoside)

  // ---- text and paragraphs ------------------------------------------------
  let indent = if noindent { 0pt } else if parspace { 18.06pt } else { _parindent }
  _indent.update(indent)
  set text(
    font: _rm12,
    size: 12pt,
    lang: lang,
    hyphenate: not nohyp,
    top-edge: 0.7em,
    bottom-edge: -0.3em,
    overhang: false,
  )
  set par(
    justify: true,
    leading: _leading,
    spacing: if parspace { _leading + 0.5 * 14.5pt * _stretch } else { _leading },
    first-line-indent: (amount: indent, all: true),
  )
  // \texttt: same size as the surrounding text (Typst's default is 0.8em)
  show raw: set text(font: _tt12)
  show raw.where(block: false): set text(size: 1em / 0.8)
  // small capitals: LM Roman Caps (cmcsc10); LM Roman 12 has no smcp feature
  show smallcaps: set text(font: _sc)
  // bold italic: cmbxti10 (LM Roman 12 has no bold italic)
  show strong: it => { show emph: set text(font: _rm10); it }
  show emph: it => { show strong: set text(font: _rm10); it }
  set math.equation(numbering: _equation-numbering)
  show math.equation.where(block: true): set block(above: 21.2pt, below: 20.7pt)
  show math.equation.where(block: true): set align(center)
  show math.equation.where(block: true): it => { it; [#metadata("equation")<elte-float-end>] }
  // \dots in math (\mathinner{\ldotp\ldotp\ldotp}): spaced dots, not the
  // tight ellipsis glyph
  show math.equation: it => {
    show "…": [#h(1em / 6).#h(1em / 6).#h(1em / 6).#h(1em / 6)]
    it
  }

  // ---- headings -------------------------------------------------------------
  set heading(numbering: _heading-numbering)

  show heading: it => {
    let num = if it.numbering == none { none } else { context _heading-num-at(it.location()) }
    if it.level == 1 {
      // \cleardoublepage / \clearpage
      [#metadata("chapter-end") <elte-chapter-end>]
      pagebreak(weak: true, to: if twoside { "odd" } else { none })
      if it.numbering != none {
        counter(figure.where(kind: image)).update(0)
        counter(figure.where(kind: table)).update(0)
        counter(figure.where(kind: raw)).update(0)
        counter(math.equation).update(0)
        // the compiled v2.4 sample restarts footnotes in every chapter
        // (despite \counterwithout{footnote}{chapter} in the class)
        counter(footnote).update(0)
      }
      let sp = _special-of(it)
      let size = _size.huge
      // report.cls: \huge\bfseries / \Huge\bfseries
      set text(size: size, weight: "bold", hyphenate: false)
      set par(first-line-indent: 0pt, justify: false, leading: 30pt * _stretch - size)
      let top = 0.7 * size
      if sp != none and sp.style == "list" {
        // tocloft list title (\cfttoctitlefont)
        let toc = it.label == <elte-toc>
        block(above: 0pt, below: if toc { 72pt } else { 59.7pt } - 0.3 * size - 0.7 * 12pt,
          width: 100%, {
          v(if toc { 153.5pt } else { 155.9pt } - top - 70.87pt - _topskip-shift)
          it.body
        })
      } else {
        block(above: 0pt, below: 60.5pt - 0.3 * size - 0.7 * 12pt, width: 100%, {
          v(178.25pt - top - 70.87pt - _topskip-shift)
          if it.numbering != none {
            block(spacing: 0pt, context {
              let app = _appendix.get()
              let n = _heading-num-at(it.location())
              if _is-hu() [#n. #_tr(if app { "appendix" } else { "chapter" })] else [#_tr(if app { "appendix" } else { "chapter" }) #n]
            })
            v(62.75pt - size)
          }
          block(spacing: 0pt, it.body)
        })
      }
    } else {
      let (size, before, after, gap) = if it.level == 2 {
        (_size.Large, 49.6pt, 32.3pt, 22pt)
      } else if it.level == 3 {
        (_size.large, 42.6pt, 28.2pt, 18pt)
      } else {
        (_size.normal, 34pt, 26.5pt, 14.5pt)
      }
      set text(size: size, weight: "bold", top-edge: 8.4pt, bottom-edge: -0.3em, hyphenate: false)
      let above = before - 0.3 * 12pt - 8.4pt
      block(
        above: above,
        below: after - 0.3 * size - 0.7 * 12pt,
        sticky: true,
        width: 100%,
        context {
          // LaTeX adds \intextsep of a preceding [H] float to the section skip;
          // Typst would collapse the two spacings, so add the difference here.
          let ends = query(selector(<elte-float-end>).before(here()))
          if ends.len() > 0 {
            let e = ends.last().location().position()
            let h = here().position()
            // listings (\lst@belowskip) leave a little more room than floats
            // after display maths LaTeX's section skip merges with
            // \belowdisplayskip: measured 11.76pt less than Typst's sum
            let kind = ends.last().value
            let extra = if kind == repr(raw) { 8.6pt } else if kind == "equation" { -11.76pt } else { _float-heading-extra }
            if e.page == h.page and h.y - e.y < above + calc.max(extra, 0pt) + 2pt { v(extra) }
          }
          // \@hangfrom: wrapped lines are indented under the title text
          let num-box = if num != none and it.level <= 3 {
            [#_heading-num-at(it.location())#if _is-hu() [.#h(0.5em)] else { h(1em) }]
          } else { none }
          let hang = if num-box == none { 0pt } else { measure(num-box).width }
          // an explicit paragraph: no first-line indent, wrapped lines hang
          par(first-line-indent: 0pt, hanging-indent: hang, justify: false,
            leading: gap * _stretch - 8.4pt - 0.3 * size)[#num-box#it.body]
        },
      )
    }
  }

  // ---- figures, tables, captions -------------------------------------------
  set figure(numbering: _per-chapter-numbering, gap: 20pt - 0.7 * 12pt)
  show figure.where(kind: image): set figure(supplement: tr("figure"))
  show figure.where(kind: table): set figure(supplement: tr("table"))
  show figure.where(kind: raw): set figure(supplement: tr("code"))
  // \intextsep around [H] floats
  show figure: set block(above: 14.8pt, below: 26.9pt)
  // listings: \lstset{aboveskip=\medskipamount}
  show figure.where(kind: raw): set block(above: 3.8pt)
  show figure.where(kind: image): it => {
    counter(figure.where(kind: "subfigure")).update(0)
    it
  }
  show figure: it => {
    if it.kind in ("definition", "theorem") { return _show-theorem(it) }
    if it.kind == "algline" { return it.body }
    if it.kind == "algorithm" {
      return block(above: 14.6pt + _leading - 8.4pt, below: 14.6pt + _leading - 8.4pt,
        width: 100%, breakable: false, {
        set par(leading: _single-leading, first-line-indent: 0pt, justify: false, spacing: _single-leading)
        set block(spacing: 0pt)
        set align(left)
        // float.sty "ruled": distances measured from the v2.4 example
        line(length: 100%, stroke: 0.8pt)
        v(2.7pt)
        block(it.caption)
        v(0.66pt)
        line(length: 100%, stroke: 0.4pt)
        v(3pt)
        block(it.body)
        v(5.4pt)
        line(length: 100%, stroke: 0.4pt)
      })
    }
    // floats are single spaced (setspace)
    set par(leading: _single-leading, spacing: _single-leading, first-line-indent: 0pt)
    it
  }
  // A float at the top of a page: LaTeX puts it at the text top (images) or \medskip below it (listings), whereas this port's body starts
  // _topskip-shift lower (see page margins). Shift it visually.
  show figure: it => {
    let float = it.kind in (image, table, raw, "algorithm")
    // (not tables: a longtable must stay breakable)
    if it.kind in (image, raw) {
      // The spacing lives on this outer block (outside the context), so it
      // collapses with neighbouring spacing as the figure's own would.
      block(above: if it.kind == raw { 3.8pt } else { 14.8pt }, below: 26.9pt, width: 100%,
        breakable: false, context {
          show figure: set block(above: 0pt, below: 0pt)
          let top = 25mm + _topskip-shift
          if it.location().position().y < top + 0.5pt {
            // a float at the top of a page: listings \medskip below the text
            // top, images at the text top (the body starts _topskip-shift lower)
            pad(top: if it.kind == raw { 4.85pt } else { -_topskip-shift }, it)
          } else { it }
        })
    } else { it }
    if float [#metadata(repr(it.kind))<elte-float-end>]
  }

  show figure.caption: it => context {
    let n = if it.numbering == none { none } else { it.counter.display(it.numbering) }
    let fig-kind = it.kind
    if fig-kind == "algorithm" {
      let head = if _is-hu() [#n. #it.supplement] else [#it.supplement #n]
      return [#strong(head) #it.body]
    }
    if fig-kind == "subfigure" {
      return {
        set text(font: _rm10, size: _size.small, hyphenate: false)
        set par(justify: false, first-line-indent: 0pt, leading: 13.6pt - _size.small)
        align(center, block([#n #it.body]))
      }
    }
    let head = if n == none { none } else if _is-hu() [#n. #it.supplement.] else [#it.supplement #n:]
    // justification=centering: centred lines, which TeX does not hyphenate
    set text(hyphenate: false)
    set par(justify: false, first-line-indent: 0pt, leading: _single-leading)
    align(center, block([#head #it.body]))
  }
  show figure.where(kind: "subfigure"): set figure(gap: 6pt)
  show figure.where(kind: "subfigure"): set block(above: 0pt, below: 0pt)
  show figure.where(kind: "algline"): set block(above: 0pt, below: 0pt)

  set table(stroke: 0.4pt, inset: (x: 6pt, top: 1.75pt, bottom: 0.75pt), align: left)
  // Cells are set ragged right and unhyphenated (LaTeX's p{} columns would
  // be justified; ragged cells read better in narrow data tables).
  show table.cell: set par(first-line-indent: 0pt, justify: false)
  show table.cell: set text(hyphenate: false)

  // ---- code listings (listings: frame=lines, gray background, numbers) -----
  set raw(theme: "elteikthesis-code.tmTheme", tab-size: 2)
  show raw.where(block: true): it => {
    set text(font: _tt10, size: _size.footnotesize, top-edge: 0.7em, bottom-edge: -0.3em)
    set par(leading: _size.footnotesize * _stretch * 1.2 - _size.footnotesize, justify: false,
      first-line-indent: 0pt)
    show raw.line: l => {
      box(width: 0pt, height: 0pt, place(bottom + right, dx: -5pt,
        text(font: _rm6, size: _size.tiny, bottom-edge: "baseline", str(l.number))))
      l.body
    }
    block(width: 100%, fill: luma(242), stroke: (top: 0.4pt, bottom: 0.4pt),
      inset: (top: 8pt, bottom: 4.5pt), align(left, it))
  }

  // ---- lists (itemize / enumerate / description; compact* when tight) -------
  let item-sep = 30.58pt - _baseline + _leading
  let list-sep = _leading + 12.8pt
  set list(indent: 0pt, body-indent: 0.5 * _em, marker: (
    box(width: 2 * _em, align(right, sym.bullet)),
    box(width: 1.7 * _em, align(right, text(weight: "bold", sym.dash.en))),
    box(width: 1.5 * _em, align(right, sym.ast.op)),
    box(width: 1.5 * _em, align(right, sym.dot.c)),
  ))
  set enum(indent: 0pt, body-indent: 0.5 * _em, full: true, numbering: (..n) => {
    let d = n.pos().len()
    let k = n.pos().last()
    let (w, s) = if d == 1 { (2 * _em, numbering("1.", k)) } else if d == 2 {
      (1.7 * _em, numbering("(a)", k))
    } else if d == 3 { (1.5 * _em, numbering("i.", k)) } else { (1.5 * _em, numbering("A.", k)) }
    box(width: w, align(right, s))
  })
  set terms(indent: 0pt, hanging-indent: 2.5 * _em, separator: h(0.5 * _em))
  show list: it => {
    if it.tight { block(above: _leading, below: _leading, it) } else {
      set par(spacing: item-sep)
      block(above: list-sep, below: list-sep, it)
    }
  }
  show enum: it => {
    if it.tight { block(above: _leading, below: _leading, it) } else {
      set par(spacing: item-sep)
      block(above: list-sep, below: list-sep, it)
    }
  }
  show terms: it => {
    set par(first-line-indent: 0pt)
    if it.tight { block(above: _leading, below: _leading, { set par(spacing: _leading); it }) } else {
      set par(spacing: item-sep)
      block(above: list-sep, below: list-sep, it)
    }
  }

  // ---- footnotes -------------------------------------------------------------
  set footnote.entry(
    separator: block(height: 3.6pt, line(length: 0.4 * _textwidth, stroke: 0.4pt)),
    clearance: 10.8pt,
    gap: 0.5em,
    indent: 0pt,
  )
  show footnote.entry: it => {
    let loc = it.note.location()
    let n = numbering(it.note.numbering, ..counter(footnote).at(loc))
    set text(font: _rm10, size: _size.footnotesize, bottom-edge: "baseline")
    show raw: set text(font: _tt10)
    set par(leading: 0.5em, first-line-indent: 0pt, hanging-indent: 0pt, spacing: 0.5em)
    block([#box(width: 1.8em, align(right, super(n)))#it.note.body])
  }

  // ---- references ----------------------------------------------------------
  show ref: it => {
    let el = it.element
    if el == none { return it }
    let num = _number-of(el)
    if num == none { return it }
    context {
      let hu = _is-hu()
      let supp = if it.supplement == auto {
        if el.func() == heading {
          if el.level == 1 { _tr(if _appendix.at(el.location()) { "appendix" } else { "chapter" }) } else { _tr("section") }
        } else if el.func() == math.equation { _tr("equation") } else { el.supplement }
      } else { it.supplement }
      let empty = supp == none or supp == [] or supp == ""
      let body = if empty { num } else if hu [#num. #supp] else [#supp~#num]
      link(el.location(), body)
    }
  }

  // ---- bibliography (biblatex, style=numeric, sorting=none) ----------------
  // \citeauthor: family names only (the bibliography style would give the
  // full "E. Dijkstra")
  show cite.where(form: "author", style: auto): it => cite(it.key, form: "author",
    supplement: it.supplement,
    style: if lang == "hu" { "citeauthor-hu.csl" } else { "citeauthor-en.csl" })
  set bibliography(title: none, style: if lang == "hu" { "biblatex-numeric-hu.csl" } else { "biblatex-numeric-en.csl" })
  // Limits of Typst's bibliography engine (hayagriva, Typst 0.15.1): the
  // BibTeX fields `version` and an @inproceedings' `organization` never reach
  // the CSL style, and `howpublished` arrives only when the entry has no
  // `note` (as the note). Put a software version in `note`; see README.
  show bibliography: it => context {
    // biblatex prints nothing (not even the heading) when nothing is cited
    if not it.full and query(cite).len() == 0 { return }
    [#heading(level: 1, numbering: none)[#tr("bibliography")] <elte-bib>]
    set par(first-line-indent: 0pt, justify: true, spacing: _leading + 4.9pt)
    // \url: \ttfamily at the text size (cmtt12)
    show link: set text(font: _tt12)
    // biblatex's punctuation tracker: no "." after a title that already
    // ends in . ? or ! inside the quotes
    show regex("[.?!…][”\"]\."): it => it.text.slice(0, -1)
    // Italic titles carry their period inside the italic run (CSL macro
    // title-italic); after "?" "!" "…" it is dropped here. After "." the
    // engine has already dropped it.
    show emph: it => { show regex("[?!…]\.$"): m => m.text.slice(0, -1); it }
    // Thesis/report type: the CSL style wraps the type (hayagriva's English
    // genre or the raw `type` field) in U+E000..U+E001; only that text is
    // rewritten, to biblatex's abbreviated bibstrings. The abbreviation's
    // own period absorbs a following ".".
    let types = if lang == "hu" {
      (phd: "Dissz.", ma: "Dipl.", tech: "Techn. jel.")
    } else {
      (phd: "PhD thesis", ma: "MA thesis", tech: "Tech. rep.")
    }
    let type-keys = (
      "Doctoral dissertation": "phd", "phdthesis": "phd",
      "Master's thesis": "ma", "mathesis": "ma",
      "technical report": "tech", "techreport": "tech",
    )
    show regex("\u{E000}[^\u{E001}]*\u{E001}\.?"): it => {
      let m = it.text.match(regex("\u{E000}([^\u{E001}]*)\u{E001}(\.?)"))
      let raw = m.captures.at(0)
      let key = type-keys.at(raw, default: none)
      let t = if key == none { raw } else { types.at(key) }
      if m.captures.at(1) != "" and not t.ends-with(".") { t + "." } else { t }
    }
    // Hungarian chapter numbers (U+E002..U+E003): ordinal for Arabic and
    // Roman numerals (magyar.lbx: \ifnumerals -> \mkbibordinal)
    show regex("\u{E002}[^\u{E003}]*\u{E003}"): it => {
      let raw = it.text.slice(3, -3)   // the markers are 3 bytes each in UTF-8
      if raw.match(regex("^([0-9]+|[IVXLCDM]+|[ivxlcdm]+)([-–,/&+ ]+([0-9]+|[IVXLCDM]+|[ivxlcdm]+))*$")) != none { raw + "." } else { raw }
    }
    it
  }

  // ---- draft option -----------------------------------------------------------
  show image: it => if draft {
    layout(region => {
      let s = measure(it, width: region.width)
      box(width: s.width, height: s.height, stroke: 0.4pt,
        align(center + horizon, text(font: _rm10, size: _size.small, if type(it.source) == str { raw(it.source) } else [image])))
    })
  } else { it }

  // ---- outline -------------------------------------------------------------
  show outline.entry: _show-outline-entry
  show outline: set par(first-line-indent: 0pt)

  // ---- front matter -----------------------------------------------------------
  if titlepage {
    make-title(
      title: title, author: author, degree: degree, supervisor: supervisor,
      affiliation: affiliation, ext-supervisor: ext-supervisor,
      ext-affiliation: ext-affiliation, university: university, faculty: faculty,
      department: department, city: city, year: year, logo: logo,
    )
  }
  if declaration != none { declaration }
  if toc { table-of-contents() }

  body
}
