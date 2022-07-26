(define-module (nfdi)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages guile-xyz)
  #:use-module (gnu packages image)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages mpi)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages pdf)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages simulation)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages xml)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (srfi srfi-1))

(define-public my-glibc-utf8-locales
  (make-glibc-utf8-locales
   glibc #:locales (list "en_US") #:name "my-glibc-utf8-locales"))

(define-public gwl
  (package
    (name "gwl")
    (version "0.4.0")
    (source
     (origin
      (method git-fetch)
      (uri
       (git-reference
        (url "https://git.savannah.gnu.org/git/gwl.git")
        (commit "bf5822ff5c804177a826984e45b78634ca9c48ec")))
      (sha256
        (base32
         "1vbfi0dzcrik66mr8gpmqim9y65zigl8f19sph5xv6dmyhnnz35c"))))
    (build-system gnu-build-system)
    (arguments
     `(#:parallel-build? #false ; for reproducibility
       #:make-flags
       '("GUILE_AUTO_COMPILE=0")))
    (native-inputs
     (list autoconf automake pkg-config texinfo graphviz))
    (inputs
     (let ((p (package-input-rewriting
               `((,guile-3.0 . ,guile-3.0-latest))
               #:deep? #false)))
       (list guix
             guile-3.0-latest
             (p guile-commonmark)
             (p guile-config)
             (p guile-drmaa)
             (p guile-gcrypt)
             (p guile-pfds)
             (p guile-syntax-highlight)
             (p guile-wisp))))
    (home-page "https://workflows.guix.info")
    (synopsis "Workflow management extension for GNU Guix")
    (description "The @dfn{Guix Workflow Language} (GWL) provides an
extension to GNU Guix's declarative language for package management to
automate the execution of programs in scientific workflows.  The GWL
can use process engines to integrate with various computing
environments.")
    ;; The Scheme modules in guix/ and gnu/ are licensed GPL3+,
    ;; the web interface modules in gwl/ are licensed AGPL3+,
    ;; and the fonts included in this package are licensed OFL1.1.
    (license (list license:gpl3+ license:agpl3+ license:silofl1.1))))


(define-public fenics-foo
  (package/inherit fenics-dolfin
    (name "fenics-foo")
    (build-system python-build-system)
    (inputs
     `(("pybind11" ,pybind11)
       ("python-matplotlib" ,python-matplotlib)
       ,@(alist-delete "python" (package-inputs fenics-dolfin))))
    (native-inputs
     `(("cmake" ,cmake-minimal)
       ("ply" ,python-ply)
       ("pytest" ,python-pytest)
       ("python-decorator" ,python-decorator)
       ("python-pkgconfig" ,python-pkgconfig)
       ,@(package-native-inputs fenics-dolfin)))
    (propagated-inputs
     `(("dolfin" ,fenics-dolfin)
       ("petsc4py" ,python-petsc4py)
       ("slepc4py" ,python-slepc4py)))
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'relax-requirements
           (lambda _
             (substitute* "python/setup.py"
               (("pybind11==") "pybind11>="))))
         (add-after 'patch-source-shebangs 'set-paths
           (lambda _
             ;; Define paths to store locations.
             (setenv "PYBIND11_DIR" (assoc-ref %build-inputs "pybind11"))
             ;; Move to python sub-directory.
             (chdir "python")))
         (add-after 'build 'mpi-setup
           ,%openmpi-setup)
         (add-before 'check 'pre-check
           (lambda _
             ;; Exclude three tests that generate
             ;; 'NotImplementedError' in matplotlib version 3.1.2.
             ;; See
             ;; <https://github.com/matplotlib/matplotlib/issues/15382>.
             ;; Also exclude tests that require meshes supplied by
             ;; git-lfs.
             (substitute* "demo/test.py"
               (("(.*stem !.*)" line)
                (string-append
                 line "\n"
                 "excludeList = [\n"
                 "'built-in-meshes', \n"
                 "'hyperelasticity', \n"
                 "'elasticity', \n"
                 "'multimesh-quadrature', \n"
                 "'multimesh-marking', \n"
                 "'mixed-poisson-sphere', \n"
                 "'mesh-quality', \n"
                 "'lift-drag', \n"
                 "'elastodynamics', \n"
                 "'dg-advection-diffusion', \n"
                 "'curl-curl', \n"
                 "'contact-vi-tao', \n"
                 "'contact-vi-snes', \n"
                 "'collision-detection', \n"
                 "'buckling-tao', \n"
                 "'auto-adaptive-navier-stokes', \n"
                 "'advection-diffusion', \n"
                 "'subdomains', \n"
                 "'stokes-taylor-hood', \n"
                 "'stokes-mini', \n"
                 "'navier-stokes', \n"
                 "'eigenvalue']\n"
                 "demos = ["
                 "d for d in demos if d[0].stem not in "
                 "excludeList]\n")))
             (setenv "HOME" (getcwd))
             ;; Restrict OpenBLAS to MPI-only in preference to MPI+OpenMP.
             (setenv "OPENBLAS_NUM_THREADS" "1")))
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (with-directory-excursion "test"
                 (invoke
                  "pytest" "unit"
                  ;; The test test_snes_set_from_options() in the file
                  ;; unit/nls/test_PETScSNES_solver.py fails and is ignored.
                  "--ignore" "unit/nls/test_PETScSNES_solver.py"
                  ;; Fails with a segfault.
                  "--ignore" "unit/io/test_XDMF.py"
                  )))))
         (add-after 'install 'install-demo-files
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((demos (string-append
                            (assoc-ref outputs "out")
                            "/share/python-dolfin/demo")))
               (mkdir-p demos)
               (with-directory-excursion "demo"
                 (for-each (lambda (file)
                             (let* ((dir (dirname file))
                                    (tgt-dir (string-append demos "/" dir)))
                               (unless (equal? "." dir)
                                 (mkdir-p tgt-dir)
                                 (install-file file tgt-dir))))
                           (find-files "." ".*\\.(py|gz|xdmf)$")))))))))
    (home-page "https://fenicsproject.org/")
    (synopsis "High-level environment for solving differential equations")
    (description
      "@code{fenics} is a computing platform for solving general classes of
problems that involve differential equations.  @code{fenics} facilitates
access to efficient methods for dealing with ordinary differential
equations (ODEs) and partial differential equations (PDEs).  Systems of
equations such as these are commonly encountered in areas of engineering,
mathematics and the physical sciences.  It is particularly well-suited to
problems that can be solved using the Finite Element Method (FEM).

@code{fenics} is the top level of the set of packages that are developed
within the FEniCS project.  It provides the python user interface to the
FEniCS core components and external libraries.")
    (license license:lgpl3+)))


(define-public cgns
  (package
   (name "cgns")
   (version "4.3.0")
   (source
    (origin
     (method url-fetch)
     (uri "https://github.com/CGNS/CGNS/archive/refs/tags/v4.3.0.tar.gz")
     (sha256
       (base32 "0cm0q2ppflfw6jy3ykk2asaqvvza17qq7wggs46yl7bkk5yyn2bp"))))
   (build-system cmake-build-system)
   (inputs (list hdf5))
   (arguments
    `(#:build-type "Release"
      ; There are no tests.
      #:phases (modify-phases %standard-phases (delete 'check))))
   (home-page "https://cgns.org/")
   (synopsis "The CFD General Notation System (CGNS) provides a general, portable, and extensible standard for the storage and retrieval of computational fluid dynamics (CFD) analysis data.")
   (description "The system consists of two parts: (1) a standard format for recording the data, and (2) software that reads, writes, and modifies data in that format.  The format is a conceptual entity established by the documentation; the software is a physical product supplied to enable developers to access and produce data recorded in that format.")
   (license license:zlib)))


(define-public paraview
  (package
   (name "paraview")
   (version "5.9.1")
   (source
    (origin
     (method url-fetch)
     (uri "https://www.paraview.org/files/v5.9/ParaView-v5.9.1.tar.xz")
     (sha256
       (base32 "13aczmfshzia324h9r2m675yyrklz2308rf98n444ppmzfv6qj0d"))))
   (build-system cmake-build-system)
   (propagated-inputs
    (list mesa qtbase-5 qtsvg glew))
   (inputs
    (list python qtxmlpatterns utfcpp pugixml qttools double-conversion lz4
          eigen cli11 netcdf gl2ps zlib libjpeg-turbo libpng libtiff expat
          freetype jsoncpp libharu libxml2 hdf5 libtheora protobuf cgns))
   (arguments
    `(#:phases
      (modify-phases
       %standard-phases
       (add-after
        'unpack 'patch-haru
        (lambda* (#:key inputs #:allow-other-keys)
                 (substitute* "VTK/ThirdParty/libharu/CMakeLists.txt"
                              (("2.4.0") "2.3.0"))
                 #t)))
      #:build-type "Release" ; Build without '-g' to save space.
      #:configure-flags
      (list
       "-DPARAVIEW_USE_PYTHON=ON"
       "-DPARAVIEW_BUILD_WITH_EXTERNAL=ON"
       "-DPARAVIEW_ENABLE_WEB:BOOL=OFF"
       "-DVTK_MODULE_USE_EXTERNAL_ParaView_vtkcatalyst=OFF"
       "-DVTK_MODULE_USE_EXTERNAL_VTK_cgns=OFF"
       "-DVTK_MODULE_USE_EXTERNAL_VTK_exprtk=OFF"
       "-DVTK_MODULE_USE_EXTERNAL_VTK_fmt=OFF"
       "-DVTK_MODULE_USE_EXTERNAL_VTK_ioss=OFF")))
   (home-page "https://www.paraview.org/")
   (synopsis "ParaView is an open-source, multi-platform data analysis and visualization application")
   (description "ParaView users can quickly build visualizations to analyze their data using qualitative and quantitative techniques. The data exploration can be done interactively in 3D or programmatically using ParaView’s batch processing capabilities.")
   (license license:bsd-3)))
