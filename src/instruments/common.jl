# Trait-based functions defaults (can be overwritten by instrument-specific versions)
orders_all(inst::AbstractInstrument2D) = min_order(inst):max_order(inst)
pixels_all(inst::AbstractInstrument2D) = min_pixels_in_order(inst):max_pixels_in_order(inst)
pixels_all(inst::AbstractInstrument1D) = min_pixel(inst):max_pixel(inst)
max_pixels_in_spectra(inst::AbstractInstrument1D) = length(pixels_all(inst))
max_pixels_in_spectra(inst::AbstractInstrument2D) = (max_order(inst)-min_order(inst)+1) * (max_pixel_in_order(inst)-min_pixel_in_order(inst)+1)

"""Read manifest containing filename, bjd, target, and optionally additional metadata from CSV file. """
function read_manifest(fn::String)
    CSV.read(fn)
end

""" Read metadata in FITS header and return data for keys in fields_str/fields as a Dict. """
function read_metadata_from_fits
end

function read_metadata_from_fits(fn::String, fields::Array{Symbol,1})
    fields_str=string.(fields)
    read_metadata_from_fits(fn,fields=fields,fields_str=fields_str)
end

function read_metadata_from_fits(fn::String, fields_str::AbstractArray{AS,1} )  where { AS<:AbstractString }
    fields = map(f->Symbol(f),fields_str)
    read_metadata_from_fits(fn,fields=fields,fields_str=fields_str)
end

function read_metadata_from_fits(fn::String; fields::Array{Symbol,1}, fields_str::AbstractArray{AS,1} )  where { AS<:AbstractString }
    @assert length(fields) == length(fields_str)
    f = FITS(fn)
    hdr = read_header(f[1])
    for field in fields_str
        @assert findfirst(isequal(field),keys(hdr)) != nothing
    end
    values = map(s->hdr[s],fields_str)
    df = Dict{Symbol,Any}(zip(fields,values))
    return df
end
