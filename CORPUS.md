# The test corpora

delfc is checked on real Delphi code, not only on its own tests. Two corpora:

| | Files | What |
|---|---|---|
| **The core** | 2,012 | The Delphi 13 RTL and VCL, DUnit, DUnitX, Spring4D, DPM (the Delphi package manager), Dev-C++, and two smaller codebases |
| **The large corpus** | 15,278 | 116 open-source repositories, shallow clones at pinned commits, listed below |

## How they're used

- **The door.** Every file is translated twice: as plain Delphi, where the output must be the
  file itself, byte for byte, and renamed to `.delf`, where any new error, warning or change is
  the door a Delphi programmer would meet. A full run over the large corpus takes about 25
  minutes on four worker processes; it runs after every change to delfc that reads or types
  more code, and every difference from the previous run is explained before the change is kept.
- **Calling units.** Each unit is also read as a used unit is, to see which of its types and
  routines a Delf file calling it would see.
- **Surveys.** Questions about how Delphi is written in practice: where conditionals stand
  and how they're shaped, how often a function's result is discarded, which symbols each
  compiler defines.
- **Comparing parsers.** The core was read by both tree-sitter-delphi13 and Olaf Monien's
  DX.DelphiLanguage; two lexer fixes found that way were merged into DX.

The surveys found bugs in delfc that no test of its own would have, and a few latent bugs in
the corpus's code; those are being reported to their authors privately first.

## The repositories

### System and runtime (15)

- [danieleteti/delphiguard](https://github.com/danieleteti/delphiguard)
- [gabr42/OmniThreadLibrary](https://github.com/gabr42/OmniThreadLibrary)
- [grijjy/DelphiPlatformTimerQueue](https://github.com/grijjy/DelphiPlatformTimerQueue)
- [grijjy/DelphiScalableClientSockets](https://github.com/grijjy/DelphiScalableClientSockets)
- [grijjy/GrijjyFoundation](https://github.com/grijjy/GrijjyFoundation)
- [MahdiSafsafi/DDetours](https://github.com/MahdiSafsafi/DDetours)
- [pleriche/FastMM4](https://github.com/pleriche/FastMM4)
- [pleriche/FastMM5](https://github.com/pleriche/FastMM5)
- [sempare/sempare-delphi-async](https://github.com/sempare/sempare-delphi-async)
- [sempare/sempare-delphi-fiber-generator](https://github.com/sempare/sempare-delphi-fiber-generator)
- [sempare/sempare-delphi-managed](https://github.com/sempare/sempare-delphi-managed)
- [VSoftTechnologies/VSoft.Awaitable](https://github.com/VSoftTechnologies/VSoft.Awaitable)
- [VSoftTechnologies/VSoft.CancellationToken](https://github.com/VSoftTechnologies/VSoft.CancellationToken)
- [VSoftTechnologies/VSoft.ThreadpoolTimer](https://github.com/VSoftTechnologies/VSoft.ThreadpoolTimer)
- [VSoftTechnologies/VSoft.WeakReferences](https://github.com/VSoftTechnologies/VSoft.WeakReferences)

### Libraries (57)

- [ahausladen/JsonDataObjects](https://github.com/ahausladen/JsonDataObjects)
- [ahausladen/PdfiumLib](https://github.com/ahausladen/PdfiumLib)
- [BatSoft-Tools/BatSoft-Library](https://github.com/BatSoft-Tools/BatSoft-Library)
- [danieleteti/arithmeticevaluator](https://github.com/danieleteti/arithmeticevaluator)
- [danieleteti/delphi-anomalies-detectors](https://github.com/danieleteti/delphi-anomalies-detectors)
- [danieleteti/delphi-expressions-evaluator](https://github.com/danieleteti/delphi-expressions-evaluator)
- [danieleteti/delphi-mqtt](https://github.com/danieleteti/delphi-mqtt)
- [danieleteti/delphi_fake_data_utils](https://github.com/danieleteti/delphi_fake_data_utils)
- [danieleteti/delphiredisclient](https://github.com/danieleteti/delphiredisclient)
- [danieleteti/delphistompclient](https://github.com/danieleteti/delphistompclient)
- [danieleteti/loggerpro](https://github.com/danieleteti/loggerpro)
- [danieleteti/mcp-server-delphi](https://github.com/danieleteti/mcp-server-delphi)
- [danieleteti/templatepro](https://github.com/danieleteti/templatepro)
- [grijjy/DelphiMongoDB](https://github.com/grijjy/DelphiMongoDB)
- [grijjy/GrijjyCloudLogger](https://github.com/grijjy/GrijjyCloudLogger)
- [IndySockets/Indy](https://github.com/IndySockets/Indy)
- [MHumm/DelphiEncryptionCompendium](https://github.com/MHumm/DelphiEncryptionCompendium)
- [ModernDelphiWorks/ModernSyntax](https://github.com/ModernDelphiWorks/ModernSyntax)
- [neslib/Neslib](https://github.com/neslib/Neslib)
- [omonien/CalculatorEngine](https://github.com/omonien/CalculatorEngine)
- [omonien/Delphi-Version-Information](https://github.com/omonien/Delphi-Version-Information)
- [omonien/DX-Encryption](https://github.com/omonien/DX-Encryption)
- [omonien/dx-library](https://github.com/omonien/dx-library)
- [omonien/DX.DelphiLanguage](https://github.com/omonien/DX.DelphiLanguage)
- [omonien/DX.DisplayInfo](https://github.com/omonien/DX.DisplayInfo)
- [omonien/DX.HttpSys](https://github.com/omonien/DX.HttpSys)
- [omonien/DX.Logger](https://github.com/omonien/DX.Logger)
- [omonien/DX.Pdfium4D](https://github.com/omonien/DX.Pdfium4D)
- [omonien/DX.Stream](https://github.com/omonien/DX.Stream)
- [omonien/DX.TOML](https://github.com/omonien/DX.TOML)
- [omonien/DXMessages](https://github.com/omonien/DXMessages)
- [omonien/DXVersion](https://github.com/omonien/DXVersion)
- [project-jedi/jcl](https://github.com/project-jedi/jcl)
- [RomanYankovsky/DelphiAST](https://github.com/RomanYankovsky/DelphiAST)
- [sempare/sempare-delphi-streams](https://github.com/sempare/sempare-delphi-streams)
- [sempare/sempare-delphi-template-engine](https://github.com/sempare/sempare-delphi-template-engine)
- [VSoftTechnologies/Delphi-Fluent-JSON](https://github.com/VSoftTechnologies/Delphi-Fluent-JSON)
- [VSoftTechnologies/Delphi-Fluent-XML](https://github.com/VSoftTechnologies/Delphi-Fluent-XML)
- [VSoftTechnologies/Delphi-Mocks](https://github.com/VSoftTechnologies/Delphi-Mocks)
- [VSoftTechnologies/DUnit-XML](https://github.com/VSoftTechnologies/DUnit-XML)
- [VSoftTechnologies/DUnitX](https://github.com/VSoftTechnologies/DUnitX)
- [VSoftTechnologies/Simple-IoC](https://github.com/VSoftTechnologies/Simple-IoC)
- [VSoftTechnologies/VSoft.AnsiConsole](https://github.com/VSoftTechnologies/VSoft.AnsiConsole)
- [VSoftTechnologies/VSoft.AntPatterns](https://github.com/VSoftTechnologies/VSoft.AntPatterns)
- [VSoftTechnologies/VSoft.Base64.Polyfill](https://github.com/VSoftTechnologies/VSoft.Base64.Polyfill)
- [VSoftTechnologies/VSoft.CommandLineParser](https://github.com/VSoftTechnologies/VSoft.CommandLineParser)
- [VSoftTechnologies/VSoft.HttpClient](https://github.com/VSoftTechnologies/VSoft.HttpClient)
- [VSoftTechnologies/VSoft.Messaging](https://github.com/VSoftTechnologies/VSoft.Messaging)
- [VSoftTechnologies/VSoft.OperationResult](https://github.com/VSoftTechnologies/VSoft.OperationResult)
- [VSoftTechnologies/VSoft.SemanticVersion](https://github.com/VSoftTechnologies/VSoft.SemanticVersion)
- [VSoftTechnologies/VSoft.System.Console](https://github.com/VSoftTechnologies/VSoft.System.Console)
- [VSoftTechnologies/VSoft.System.TimeProvider](https://github.com/VSoftTechnologies/VSoft.System.TimeProvider)
- [VSoftTechnologies/VSoft.Ulid](https://github.com/VSoftTechnologies/VSoft.Ulid)
- [VSoftTechnologies/VSoft.Uri](https://github.com/VSoftTechnologies/VSoft.Uri)
- [VSoftTechnologies/VSoft.UUIDv7](https://github.com/VSoftTechnologies/VSoft.UUIDv7)
- [VSoftTechnologies/VSoft.WindowsCredentialManager](https://github.com/VSoftTechnologies/VSoft.WindowsCredentialManager)
- [VSoftTechnologies/VSoft.YAML](https://github.com/VSoftTechnologies/VSoft.YAML)

### Frameworks (5)

- [danieleteti/columbusegg4delphi](https://github.com/danieleteti/columbusegg4delphi)
- [danieleteti/delphidicontainer](https://github.com/danieleteti/delphidicontainer)
- [danieleteti/delphimvcframework](https://github.com/danieleteti/delphimvcframework)
- [grijjy/MvvmStarterKit](https://github.com/grijjy/MvvmStarterKit)
- [synopse/mORMot2](https://github.com/synopse/mORMot2)

### Components (5)

- [cnpack/cnvcl](https://github.com/cnpack/cnvcl)
- [JAM-Software/Virtual-TreeView](https://github.com/JAM-Software/Virtual-TreeView)
- [project-jedi/jvcl](https://github.com/project-jedi/jvcl)
- [TurboPack/SynEdit](https://github.com/TurboPack/SynEdit)
- [VSoftTechnologies/VSoft.VirtualListView](https://github.com/VSoftTechnologies/VSoft.VirtualListView)

### IDE plug-ins (5)

- [cnpack/cnwizards](https://github.com/cnpack/cnwizards)
- [omonien/DX.Blame](https://github.com/omonien/DX.Blame)
- [omonien/GetItManager](https://github.com/omonien/GetItManager)
- [ottigeda/gexperts](https://github.com/ottigeda/gexperts)
- [VSoftTechnologies/VSoft.ExternalModDetector](https://github.com/VSoftTechnologies/VSoft.ExternalModDetector)

### Applications (6)

- [danieleteti/mockjsonapi](https://github.com/danieleteti/mockjsonapi)
- [omonien/AetherOrbits](https://github.com/omonien/AetherOrbits)
- [omonien/DX.Comply](https://github.com/omonien/DX.Comply)
- [omonien/DX.HttpDiag](https://github.com/omonien/DX.HttpDiag)
- [VSoftTechnologies/DelphiUsesAnalyzer](https://github.com/VSoftTechnologies/DelphiUsesAnalyzer)
- [VSoftTechnologies/DPackGen](https://github.com/VSoftTechnologies/DPackGen)

### Samples (6)

- [danieleteti/dmvcframeworktheofficialguideexamples](https://github.com/danieleteti/dmvcframeworktheofficialguideexamples)
- [grijjy/EntityComponentSystems](https://github.com/grijjy/EntityComponentSystems)
- [grijjy/JustAddCode](https://github.com/grijjy/JustAddCode)
- [omonien/DAPUG-2026](https://github.com/omonien/DAPUG-2026)
- [sempare/sempare-delphi-fts-expression-demo](https://github.com/sempare/sempare-delphi-fts-expression-demo)
- [sempare/sempare-devto-examples](https://github.com/sempare/sempare-devto-examples)

### Paul McGee's own, functional style (8)

- [pmcgee69/Comp_Dirs_with_Spring4D](https://github.com/pmcgee69/Comp_Dirs_with_Spring4D)
- [pmcgee69/Enum-to-Set](https://github.com/pmcgee69/Enum-to-Set)
- [pmcgee69/Fluent-ID-example](https://github.com/pmcgee69/Fluent-ID-example)
- [pmcgee69/fluent_errors](https://github.com/pmcgee69/fluent_errors)
- [pmcgee69/Functional-Concepts](https://github.com/pmcgee69/Functional-Concepts)
- [pmcgee69/FunctionalLib](https://github.com/pmcgee69/FunctionalLib)
- [pmcgee69/Testing-Tuple-Ideas](https://github.com/pmcgee69/Testing-Tuple-Ideas)
- [pmcgee69/WTFR_Coroutines_DevDays2024](https://github.com/pmcgee69/WTFR_Coroutines_DevDays2024)

### Paul McGee's own (9)

- [pmcgee69/Advent-of-Code-2022](https://github.com/pmcgee69/Advent-of-Code-2022)
- [pmcgee69/Advent-of-Code-2024](https://github.com/pmcgee69/Advent-of-Code-2024)
- [pmcgee69/Code-Challenges](https://github.com/pmcgee69/Code-Challenges)
- [pmcgee69/D3.js-Delphi](https://github.com/pmcgee69/D3.js-Delphi)
- [pmcgee69/double-precision-to-enum-perf-test](https://github.com/pmcgee69/double-precision-to-enum-perf-test)
- [pmcgee69/Exceptions-Cost-in-Delphi](https://github.com/pmcgee69/Exceptions-Cost-in-Delphi)
- [pmcgee69/regex_test1](https://github.com/pmcgee69/regex_test1)
- [pmcgee69/RSA_Explore](https://github.com/pmcgee69/RSA_Explore)
- [pmcgee69/test_opengl](https://github.com/pmcgee69/test_opengl)
