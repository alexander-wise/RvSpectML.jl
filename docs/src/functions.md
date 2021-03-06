```@meta
CurrentModule = RvSpectML
```
# Functions Exported by RvSpectML

```@contents
Pages = ["functions.md"]
Depth = 3
```

## General purpose
```@autodocs
Modules = [RvSpectML ]
Private = false
Order = [:function ]
```

## RV-Related Algorithms
```@autodocs
Modules = [ RvSpectML.DCPCA, RvSpectML.LineFinder] #, RvSpectML.PPCA ]
Private = false
Order = [:function ]
```

## Interpolation Algorithms
```@autodocs
Modules = [RvSpectML.LinearInterpolation, RvSpectML.SincInterpolation, RvSpectML.TemporalGPInterpolation ]  # RvSpectML.GPInterpolation,
Private = false
Order = [:function ]
```

## Other
```@autodocs
Modules = [Pipeline  ]
Private = false
Order = [:function]
```
