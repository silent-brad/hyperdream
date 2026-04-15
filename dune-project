(lang dune 3.0)
(name hyperdream)
(version 0.1.0)

(generate_opam_files true)

(source (github silent-brad/hyperdream))
(license ISC)
(authors "Brad White")
(maintainers "Brad White")

(package
 (name hyperdream)
 (synopsis "MirageOS/Datastar web framework for server-driven real-time applications")
 (depends
  (ocaml (>= 4.14.0))
  (dune (>= 3.0))
  (lwt (>= 5.6.0))
  (h1 (>= 0.17.0))
  (paf (>= 0.7.0))
  (datastar (>= 0.1.0))
  (jingoo (>= 1.5.0))
  (yojson (>= 2.0.0))
  (digestif (>= 1.1.0))
  (uri (>= 4.0.0))
  (base64 (>= 3.5.0))
  (mirage-crypto-rng (>= 1.0.0))
  tcpip
  paf-cohttp))
