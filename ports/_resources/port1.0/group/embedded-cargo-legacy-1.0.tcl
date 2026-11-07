# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# embedded-cargo-legacy 1.0  —  backport-toolkit Overlay-PortGroup
# ---------------------------------------------------------------------------
# Fuer C/C++-Ports, deren Buildsystem INTERN cargo/rustc aufruft (Node V8-Temporal,
# Firefox, librsvg, ...). Biegt diesen eingebetteten Rust-Build auf die NATIVE
# macOS-10.9-Toolchain + MacportsLegacySupport um, damit die Rust-Objekte auf 10.9
# lauffaehig sind.
#
# Diese PortGroup macht NUR das Rust-Toolchain-Wiring. Die C-Seite (MLS-Include-Pfad
# und -Link) bleibt Sache von `PortGroup legacysupport` — beide zusammen einbinden.
#
# Hintergrund/Technik: memory embedded-rust-on-10-9-technique. Kurz:
#  * Unser natives rustc/cargo (port:rust/port:cargo) laeuft selbst auf 10.9 -> alle
#    Rust-std-Symbole sind bereits von MLS abgedeckt.
#  * rustc taggt x86_64-apple-darwin-Objekte auf 10.12 (Upstream-Floor); in ein
#    10.9-Binary gemergt irrelevant. MACOSX_DEPLOYMENT_TARGET=10.9 gibt nur eine
#    Warnung, kein Fehler.
#  * Von cargo GELINKTE Host-Artefakte (build-scripts, proc-macros) brauchen den
#    MLS-Link-Arg -> hier via RUSTFLAGS gesetzt. staticlib-Crates linkt cargo nicht;
#    deren Symbole loesen sich am finalen C++/clang-Link des Host-Ports gegen
#    -lMacportsLegacySupport (z.B. Node via common.gypi-MLS-Patch).
#
# ===  ACHTUNG — nicht generisch abbildbar, per-Port erforderlich:  ==============
# Der cargo-Aufruf des Ports darf KEIN `--target <triple>` uebergeben. Mit --target
# scoped cargo RUSTFLAGS von den Host-build-scripts/proc-macros WEG -> der MLS-
# Link-Arg erreicht sie nicht -> undefined _openat/_unlinkat/_fdopendir$INODE64 auf
# 10.9. Ohne --target ist host==target und RUSTFLAGS greift ueberall. Auf nativem
# 10.9-Intel gibt es kein Rosetta, fuer das --target upstream gedacht ist. Jeder Port
# muss das in SEINEM Buildsystem sicherstellen (Node: patch-crates-no-target.diff).
# ===============================================================================

options embedded_cargo.clang_major
default embedded_cargo.clang_major 22

# Native Rust-Toolchain als Build-Abhaengigkeit.
depends_build-append    port:rust \
                        port:cargo

# Zusammenbau der Pfade (nach Portfile-Auswertung, damit clang_major-Override greift).
namespace eval embedded_cargo {}
proc embedded_cargo::setup {} {
    global prefix workpath
    set cc  ${prefix}/bin/clang-mp-[option embedded_cargo.clang_major]
    set mls ${prefix}/lib/libMacportsLegacySupport.a

    # CARGO/RUSTC: configure detektiert die Rust-Toolchain hierueber; cargo waehlt
    # rustc via RUSTC. CARGO_HOME lokal, weil der Build-User /Users/<user>/.cargo
    # NICHT sieht (sonst fehlen dessen [target...]-rustflags komplett).
    foreach phase {configure build} {
        ${phase}.env-append CARGO=${prefix}/bin/cargo
        ${phase}.env-append RUSTC=${prefix}/bin/rustc
        ${phase}.env-append CARGO_HOME=${workpath}/cargo-home
    }

    # RUSTFLAGS nur im build-Phase-Env (configure macht nur Versions-Checks, keinen
    # Link). Linker = natives clang-22, plus statisches MLS als Link-Arg -> loest die
    # Rust-std-10.10+-Symbole in den von cargo gelinkten Executables/dylibs.
    build.env-append "RUSTFLAGS=-C linker=${cc} -C link-arg=${mls}"

    # sccache als rustc-Wrapper fuer den eingebetteten Rust-Build (2026-11-07).
    # Nur im build-Env, aus demselben Grund wie RUSTFLAGS: configure macht nur
    # Versions-Checks, kompiliert nicht.
    #
    # SCCACHE_DIR liegt bewusst UNTERHALB von ccache_dir. Die MacPorts-Sandbox gibt
    # zum Schreiben nur $workpath und -- bei eingeschaltetem ccache -- $ccache_dir
    # frei (portsandbox.tcl). In $workpath waere der Cache nach jedem `clean` weg,
    # also wertlos. Ist configure.ccache aus, ist der Pfad nicht beschreibbar; dann
    # sccache lieber weglassen als still ins Leere cachen.
    #
    # Eigener Server-Port: der interaktive Benutzer faehrt seinen sccache-Server auf
    # dem Standardport 4226 mit EIGENEM Cache-Verzeichnis. Ohne Trennung wuerde der
    # Build-User sich mit dessen Server verbinden und in dessen Cache schreiben.
    #
    # CARGO_HOME oben zeigt in den workpath, d.h. ~/.cargo des interaktiven Benutzers
    # (und dessen rustc-wrapper) wird hier bewusst NICHT gelesen -- deshalb muss der
    # Wrapper hier explizit gesetzt werden.
    global ccache_dir
    if {[file executable ${prefix}/bin/sccache] && [option configure.ccache]} {
        build.env-append RUSTC_WRAPPER=${prefix}/bin/sccache
        build.env-append SCCACHE_DIR=${ccache_dir}/sccache
        build.env-append SCCACHE_SERVER_PORT=4227
    } else {
        ui_debug "embedded-cargo-legacy: sccache nicht aktiv (fehlt oder configure.ccache aus)"
    }
}
port::register_callback embedded_cargo::setup
