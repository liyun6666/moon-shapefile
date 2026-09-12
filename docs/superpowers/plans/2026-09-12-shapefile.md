# Shapefile Implementation Plan

> **For agentic workers:** use superpowers:subagent-driven-development for independent package work and local execution for dependent integration.

**Goal:** Deliver real Shapefile IO, filtering and GeoJSON conversion to liyun6666/moonbit9.
**Architecture:** Checked byte codecs feed typed SHP records and independent DBF records. Dataset layer preserves physical alignment. Native CLI performs filesystem IO.
**Tech Stack:** MoonBit 0.10.9+, Python PyShp for external interoperability tests.
**Spec:** docs/design.md

## Global constraints

- Repository and package: liyun6666/moonbit9; MIT; primary language MoonBit.
- More than 4000 effective implementation lines, tests counted separately.
- At least ten commits tied to actual functional milestones; no empty commits.
- No MultiPatch, Memo, reprojection, network or ZIP API.

## Tasks and acceptance checkpoints

- [ ] Checked binary readers/writers: binary.mbt + binary_wbtest.mbt. Read literal BE 9994 and LE double 1.0; truncated bytes return ShapeError. Run moon test, implement, rerun, commit.
- [ ] Geometry model/validation: geometry.mbt, geometry_wbtest.mbt. Test invalid bounds, type dimensions, ring closure, parts. Constructors follow docs/design.md. Run failing cases then add validator and commit.
- [ ] DBF codec (independent agent): dbf/*.mbt. Literal dBASE fields decode with physical deletion flag, UTF-8/Latin1 codec, exact decimals and valid dates; roundtrip and malformed tests. Commit read and write milestones separately through coordinator.
- [ ] SHP reading: header.mbt, reader.mbt. Independent point-file fixture has one point (1,2); length/type/count corruption raises errors. Add all shape families with allocation limits. Run tests then commit.
- [ ] SHX validation: index.mbt. Valid index passes; wrong offset/content length/type fails. Test before implementation and commit.
- [ ] SHP writing: writer.mbt. Independent byte offsets and reference PyShp decoder verify 2D and Z/M output. Run tests then commit.
- [ ] Geometry/GeoJSON: geojson.mbt. Nested hole and island become correct Polygon/MultiPolygon with RFC orientation. Crossing rings fail explicitly. Test then implement, run, commit.
- [ ] Dataset: dataset.mbt. Join physical records; deleted row does not shift attributes; projection/filter preserve records. Test before implementation and commit.
- [ ] CLI and workflows: cmd/main, examples. Real file commands inspect/geojson/filter/create. Integration test using subprocess temporary directory; invalid arguments return nonzero. Commit.
- [ ] Cross-language regression: scripts/interop.py. PyShp writer -> MoonBit decoder and vice versa for all families, fields, null/deleted rows. Run reference version pinned; commit.
- [ ] Documentation/CI/publishing: README, LICENSE, THIRD_PARTY, proposal, workflow. Run check/build/test/fmt/info and source count, review, commit; push to confirmed repository only when access exists; publish if authenticated.

## Ledger

- Plan approved by user's selection and subsequent OK; execute continuously.
- Fresh empty clone has no tests yet. Toolchain 0.10.9 available.
