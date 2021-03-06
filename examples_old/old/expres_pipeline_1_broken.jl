using Pkg
 Pkg.activate(".")

verbose = true
if verbose   println("# Loading RvSpecML")    end
 using RvSpectML
 if verbose   println("# Loading other packages")    end
 using DataFrames, Query, Statistics
 using Dates

# USER:  The default paths that specify where datafiles can be entered here or overridden in examples/data_paths.jl
target_subdir = "101501"   # USER: Replace with directory of your choice
 fits_target_str = "101501"
 output_dir = "examples/output"
 default_paths_to_search = [pwd(),"examples",joinpath(pkgdir(RvSpectML),"examples"),"/gpfs/group/ebf11/default/ebf11/expres/inputs"]

 make_plots = true
 write_ccf_to_csv = true
 write_rvs_to_csv = true
 write_order_ccf_to_csv = true
 write_template_to_csv = true
 write_spectral_grid_to_jld2 = true
 write_dcpca_to_csv = true
 write_lines_to_csv = true

has_loaded_data = false
 has_computed_ccfs = false
 has_computed_rvs = false
 has_computed_order_ccfs = false
 has_computed_template = false
 has_computed_dcpca = false
 has_found_lines = false
 has_computed_ccfs2 = false
 has_computed_rvs2 = false
 has_computed_template2 = false
 has_computed_dcpca2 = false

if !has_loaded_data
  if verbose println("# Finding what data files are avaliable.")  end
  df_files = make_manifest(target_subdir, EXPRES )

  if verbose println("# Reading in customized parameters.")  end
  eval(code_to_include_param_jl())

  if verbose println("# Reading in FITS files.")  end
  @time expres_data = map(EXPRES.read_data,eachrow(df_files_use))
  has_loaded_data = true

  if verbose println("# Extracting order list timeseries from spectra.")  end
  order_list_timeseries = RvSpectML.make_order_list_timeseries(expres_data)
  order_list_timeseries = RvSpectML.filter_bad_chunks(order_list_timeseries,verbose=true)
  RvSpectML.normalize_spectra!(order_list_timeseries,expres_data);
end

if !has_computed_ccfs || true
if verbose println("# Reading line list for CCF: ", linelist_for_ccf_filename, ".")  end
 lambda_range_with_good_data = get_λ_range(expres_data)
 espresso_filename = joinpath(pkgdir(RvSpectML),"data","masks",linelist_for_ccf_filename)
 espresso_df = RvSpectML.read_linelist_espresso(espresso_filename)
 line_list_df = EXPRES.filter_line_list(espresso_df,first(expres_data).inst)

if verbose println("# Removing lines with telluric contamination.")  end    # Currently only works for EXPRES data
 Δv_to_avoid_tellurics = 14000.0
 line_list_to_search_for_tellurics = copy(line_list_df)
 line_list_to_search_for_tellurics.lambda_lo = line_list_to_search_for_tellurics.lambda./calc_doppler_factor(Δv_to_avoid_tellurics)
 line_list_to_search_for_tellurics.lambda_hi = line_list_to_search_for_tellurics.lambda.*calc_doppler_factor(Δv_to_avoid_tellurics)
 chunk_list_timeseries = RvSpectML.make_chunk_list_timeseries(expres_data,line_list_to_search_for_tellurics)
 line_list_to_search_for_tellurics.min_telluric_model_all_obs = RvSpectML.find_worst_telluric_in_each_chunk( chunk_list_timeseries, expres_data)
 line_list_no_tellurics_df = line_list_to_search_for_tellurics |> @filter(_.min_telluric_model_all_obs == 1.0) |> DataFrame
 #=
 Δv_to_avoid_tellurics = RvSpectMLBase.max_bc # default_Δv_to_avoid_tellurics
 line_list_no_tellurics_df.lambda_lo = line_list_no_tellurics_df.lambda./calc_doppler_factor(Δv_to_avoid_tellurics)
 line_list_no_tellurics_df.lambda_hi = line_list_no_tellurics_df.lambda.*calc_doppler_factor(Δv_to_avoid_tellurics)
 #find_overlapping_chunks(line_list_no_tellurics_df)
 #chunk_list_no_tellurics_merged_df = chunk_list_no_tellurics_merged_df |> @take(1) |> DataFrame
 #chunk_list_no_tellurics_merged_df = RvSpectML.merge_chunks(line_list_no_tellurics_df)
 #@assert find_overlapping_chunks(chunk_list_no_tellurics_merged_df) == nothing
 #chunk_list_timeseries = RvSpectML.make_chunk_list_timeseries(expres_data,chunk_list_no_tellurics_merged_df)
 chunk_list_timeseries = RvSpectML.make_chunk_list_timeseries(expres_data,line_list_no_tellurics_df)
 #chunk_list_timeseries = RvSpectML.make_chunk_list_timeseries(expres_data,chunk_list_no_tellurics_merged_df)
=#

 # Compute CCF's & measure RVs
if verbose println("# Computing CCF.")  end
 mask_shape = RvSpectML.CCF.TopHatCCFMask(order_list_timeseries.inst, scale_factor=tophap_ccf_mask_scale_factor)
 line_list = RvSpectML.CCF.BasicLineList(line_list_df.lambda, line_list_df.weight)
 line_list = RvSpectML.CCF.BasicLineList(line_list_no_tellurics_df.lambda, line_list_no_tellurics_df.weight)
 #line_list = RvSpectML.CCF.BasicLineList(chunk_list_no_tellurics_merged_df.lambda, chunk_list_no_tellurics_merged_df.weight)
 ccf_plan = RvSpectML.CCF.BasicCCFPlan(mask_shape = mask_shape, line_list=line_list, midpoint=ccf_mid_velocity)
 v_grid = RvSpectML.CCF.calc_ccf_v_grid(ccf_plan)
 @time ccfs = RvSpectML.CCF.calc_ccf_chunklist_timeseries(order_list_timeseries, ccf_plan)
 #@time ccfs = RvSpectML.CCF.calc_ccf_chunklist_timeseries(chunk_list_timeseries, ccf_plan)
 # Write CCFs to file
 if write_ccf_to_csv
    using CSV
    CSV.write(joinpath(output_dir,target_subdir * "_ccfs.csv"),Tables.table(ccfs',header=Symbol.(v_grid)))
 end
 has_computed_ccfs = true
end

#make_plots = true
if make_plots
   using Plots
   t_idx = 1:size(ccfs,2)
   using Plots
   #plot(v_grid,ccfs[:,t_idx]./maximum(ccfs[:,t_idx],dims=1),label=:none)
   plot(v_grid,ccfs[:,t_idx],label=:none)
   xlabel!("v (m/s)")
   ylabel!("CCF")
 end


if !has_computed_rvs
 if verbose println("# Measuring RVs from CCF.")  end
 rvs_ccf_gauss = RvSpectML.RVFromCCF.measure_rv_from_ccf(v_grid,ccfs,fit_type = "gaussian")
 # Store estimated RVs in metadata
 map(i->order_list_timeseries.metadata[i][:rv_est] = rvs_ccf_gauss[i]-mean(rvs_ccf_gauss), 1:length(order_list_timeseries) )
 if write_rvs_to_csv
    using CSV
    CSV.write(joinpath(output_dir,target_subdir * "_rvs_ccf.csv"),DataFrame("Time [MJD]"=>order_list_timeseries.times,"CCF RV [m/s]"=>rvs_ccf_gauss))
 end
 has_computed_rvs = true
end

if !has_computed_order_ccfs  # Compute order CCF's & measure RVs
tstart = now()    # Compute CCFs for each order
 # TODO:  Need to mask tellurics somehow
 RvSpectML.CCF.calc_order_ccf_chunklist_timeseries(order_list_timeseries, ccf_plan)
 #=
 orders_to_use = RvSpectML.orders_to_use_default(chunk_list_timeseries.inst)
 num_obs = length(chunk_list_timeseries)
 order_ccfs = Array{Float64,3}(undef,length(v_grid), length(orders_to_use), num_obs)
 for (i,ord) in enumerate(orders_to_use)
     chunk_list_order_timeseries = RvSpectML.extract_chunk_list_timeseries_for_order(order_list_timeseries, ord)
     if isnothing(chunk_list_order_timeseries)
        println("# Warning: No usable lines in order = ", ord)
        order_ccfs[:,i,:] .= 0.0
     else
        order_ccfs[:,i,:] .= RvSpectML.CCF.calc_ccf_chunklist_timeseries(order_list_order_timeseries, ccf_plan)

     end
 end
 =#
 println("# Order CCFs runtime: ", now()-tstart)

 if write_order_ccf_to_csv
    using CSV
    inst = EXPRES.EXPRES2D()
    for (i, order) in orders_to_use
      if !(sum(order_ccfs[:,i,:]) > 0)   continue    end
      local t = Tables.table( order_ccfs[:,i,:]', header=Symbol.(v_grid) )
      CSV.write(joinpath(output_dir,target_subdir * "_ccf_order=" * string(order) * ".csv"),t)
    end
 end
 has_computed_order_ccfs = true
end

if !has_computed_template
   if verbose println("# Making template spectra.")  end
   @time ( spectral_orders_matrix, f_mean, var_mean, deriv, deriv2, order_grids )  = RvSpectML.make_template_spectra(order_list_timeseries)

   if write_template_to_csv
      using CSV
      CSV.write(joinpath(output_dir,target_subdir * "_template.csv"),DataFrame("λ"=>spectral_orders_matrix.λ,"flux_template"=>f_mean,"var"=>var_mean, "dfluxdlnλ_template"=>deriv,"d²fluxdlnλ²_template"=>deriv2))
   end
   if write_spectral_grid_to_jld2
      using JLD2, FileIO
      save(joinpath(output_dir,target_subdir * "_matrix.jld2"), Dict("λ"=>spectral_orders_matrix.λ,"spectra"=>spectral_orders_matrix.flux,"var_spectra"=>spectral_orders_matrix.var,"flux_template"=>f_mean,"var"=>var_mean, "dfluxdlnλ_template"=>deriv,"d²fluxdlnλ²_template"=>deriv2))
   end
   has_computed_template = true
end

if !has_computed_dcpca
   if verbose println("# Performing Doppler constrained PCA analysis.")  end
   using MultivariateStats
   dcpca_out, M = RvSpectML.DCPCA.doppler_constrained_pca(spectral_orders_matrix.flux, deriv, rvs_ccf_gauss)
   frac_var_explained = 1.0.-cumsum(principalvars(M))./tvar(M)
   println("# Fraction of variance explained = ", frac_var_explained[1:min(5,length(frac_var_explained))])
   if write_dcpca_to_csv
      using CSV
      CSV.write(joinpath(output_dir,target_subdir * "_dcpca_basis.csv"),  Tables.table(M.proj) )
      CSV.write(joinpath(output_dir,target_subdir * "_dcpca_scores.csv"), Tables.table(dcpca_out) )
   end
   has_computed_dcpca = true
end


if make_plots  # Ploting results from DCPCA
  using Plots
  # Set parameters for plotting analysis
  plt_order = 42
  plt_order_pix = 4500:5000
  plt = scatter(frac_var_explained, xlabel="Number of PCs", ylabel="Frac Variance Unexplained")
  display(plt)
end

if make_plots
  plt_order = 13
  RvSpectML.plot_basis_vectors(order_grids, f_mean, deriv, M.proj, idx_plt = spectral_orders_matrix.chunk_map[plt_order], num_basis=3 )
  #xlims!(5761.5,5766)
end

if make_plots
  RvSpectML.plot_basis_scores(order_list_timeseries.times, rvs_ccf_gauss, dcpca_out, num_basis=3 )
end

if make_plots
  RvSpectML.plot_basis_scores_cor( rvs_ccf_gauss, dcpca_out, num_basis=3)
end

has_found_lines = false
write_lines_to_csv= false
if !has_found_lines
   if verbose println("# Performing fresh search for lines in template spectra.")  end
   cl = ChunkList(map(grid->ChuckOfSpectrum(spectral_orders_matrix.λ,f_mean, var_mean, grid), spectral_orders_matrix.chunk_map))
   spectral_orders_matrix = nothing # We're done with this, so can release memory
   GC.gc()
   lines_in_template = RvSpectML.LineFinder.find_lines_in_chunklist(cl)
   if verbose println("# Finding above lines in all spectra.")  end
   @time fits_to_lines = RvSpectML.LineFinder.fit_all_lines_in_chunklist_timeseries(order_list_timeseries, lines_in_template )

   if verbose println("# Rejecting lines that have telluric contamination at any time.")  end
   telluric_info = RvSpectML.LineFinder.find_worst_telluric_in_each_line_fit!(fits_to_lines, order_list_timeseries, expres_data )

   # Look at distribution of standard deviations for line properties
    fit_distrib = fits_to_lines |> @groupby(_.line_id) |>
            @map( { median_a=median(_.fit_a), median_b=median(_.fit_b), median_depth=median(_.fit_depth), median_σ²=median(_.fit_σ²), median_λc=median(_.fit_λc),
                   std_a=std(_.fit_a), std_b=std(_.fit_b), std_depth=std(_.fit_depth), std_σ²=std(_.fit_σ²), std_λc=std(_.fit_λc), min_telluric_model_all_obs=minimum(_.min_telluric_model_this_obs), line_id=_.line_id } ) |>
            @filter(_.min_telluric_model_all_obs == 1.0 ) |> # No telluric in any observations
            @filter(_.std_b < 0.257) |>     # ~90th quantile
            @filter( 0.001 < _.median_σ² ) |>  # ~99th quantile
            @filter( _.std_σ² < 0.00844) |>  # ~99th quantile
            @filter( _.median_depth > 0.05 ) |>  # ~99th quantile
            @filter( _.std_depth < 0.11 ) |>  # ~95th quantile
            #@filter( -0.25 < _.median_b < 0.25) |>  #~5th to 95th percentiles
            DataFrame # ~75th quantile
      good_lines = fit_distrib |> @filter(_.std_λc < 0.0316 ) |> DataFrame
      bad_lines = fit_distrib |> @filter(_.std_λc > 0.0316 ) |> DataFrame
      #scatter(good_lines.median_σ², good_lines.median_depth )
      #scatter!(bad_lines.median_σ², bad_lines.median_depth )
      lines_to_try = lines_in_template[first.(good_lines[!,:line_id]),:]


      if write_lines_to_csv
         using CSV
         CSV.write(joinpath(output_dir,target_subdir * "_linefinder_lines.csv"), lines_in_template )
         CSV.write(joinpath(output_dir,target_subdir * "_linefinder_line_fits.csv"), fits_to_lines )
         CSV.write(joinpath(output_dir,target_subdir * "_linefinder_line_fits_clean.csv"), lines_to_try )
         fits_to_lines = nothing
         telluric_info = nothing
         fit_distrib = nothing
         good_lines = nothing
         bad_lines = nothing
         GC.gc()
      end

   has_found_lines = true
end

if has_computed_ccfs2
   if verbose println("# Computing CCFs with new line list.")  end
   #mask_shape = RvSpectML.CCF.TopHatCCFMask(order_list_timeseries.inst, scale_factor=tophap_ccf_mask_scale_factor)
   perm = sortperm(lines_to_try.fit_λc)
   line_list2 = RvSpectML.CCF.BasicLineList(lines_to_try.fit_λc[perm], lines_to_try.fit_depth[perm].*lines_to_try.fit_a[perm] )
   ccf_plan2 = RvSpectML.CCF.BasicCCFPlan(mask_shape = mask_shape, line_list=line_list2, midpoint=0.0)
   v_grid2 = RvSpectML.CCF.calc_ccf_v_grid(ccf_plan2)
   @time ccfs2 = RvSpectML.CCF.calc_ccf_chunklist_timeseries(order_list_timeseries, ccf_plan2)
   # Write CCFs to file
   if write_ccf_to_csv
      using CSV
      CSV.write(joinpath(output_dir,target_subdir * "_ccfs2.csv"),Tables.table(ccfs2',header=Symbol.(v_grid)))
   end
   has_computed_ccfs2 = true
end

if !has_computed_rvs2
 if verbose println("# Measuring RVs from CCF.")  end
 #rvs_ccf_gauss = [ RvSpectML.RVFromCCF.measure_rv_from_ccf(v_grid,ccfs[:,i],fit_type = "gaussian") for i in 1:length(order_list_timeseries) ]
 rvs_ccf_gauss2 = RvSpectML.RVFromCCF.measure_rv_from_ccf(v_grid2,ccfs2,fit_type = "gaussian")
 # Store estimated RVs in metadata
 map(i->order_list_timeseries.metadata[i][:rv_est] = rvs_ccf_gauss2[i]-mean(rvs_ccf_gauss2), 1:length(order_list_timeseries) )
 if write_rvs_to_csv
    using CSV
    CSV.write(joinpath(output_dir,target_subdir * "_rvs_ccf2.csv"),DataFrame("Time [MJD]"=>order_list_timeseries.times,"CCF RV [m/s]"=>rvs_ccf_gauss))
 end
 has_computed_rvs2 = true
end

if !has_computed_template2
   # Do we need to expand region around lines to include more of wings for DCPCA to work well?
   # If so, should probably avoid tellurics encroaching on exapnded wavelength region.  Sigh.
   chunk_list_df2 = lines_to_try |> @select(:fit_min_λ,:fit_max_λ) |> @rename(:fit_min_λ=>:lambda_lo, :fit_max_λ=>:lambda_hi) |> DataFrame
   chunk_list_timeseries2 = RvSpectML.make_chunk_list_timeseries(expres_data,chunk_list_df2)

   # Check that no NaN's included
   (chunk_list_timeseries2, chunk_list_df2) = RvSpectML.filter_bad_chunks(chunk_list_timeseries2,chunk_list_df2)
   println(size(chunk_list_df2), " vs ", num_chunks(chunk_list_timeseries2) )


   if verbose println("# Making template spectra.")  end
   @time ( spectral_orders_matrix2, f_mean2, var_mean2, deriv_2, deriv2_2, order_grids2 )  = RvSpectML.make_template_spectra(chunk_list_timeseries2)

   if write_template_to_csv
      using CSV
      CSV.write(joinpath(output_dir,target_subdir * "_template2.csv"),DataFrame("λ"=>spectral_orders_matrix2.λ,"flux_template"=>f_mean2,"var"=>var_mean2, "dfluxdlnλ_template"=>deriv_2,"d²fluxdlnλ²_template"=>deriv2_2))
   end
   if write_spectral_grid_to_jld2
      using JLD2, FileIO
      save(joinpath(output_dir,target_subdir * "_matrix2.jld2"), Dict("λ"=>spectral_orders_matrix2.λ,"spectra"=>spectral_orders_matrix2.flux,"var_spectra"=>spectral_orders_matrix2.var,"flux_template"=>f_mean2,"var"=>var_mean2, "dfluxdlnλ_template"=>deriv_2,"d²fluxdlnλ²_template"=>deriv2_2))
   end
   has_computed_template2 = true
end

has_computed_dcpca2 = false
if !has_computed_dcpca2
   if verbose println("# Performing Doppler constrained PCA analysis.")  end
   using MultivariateStats
   dcpca2_out, M2 = RvSpectML.DCPCA.doppler_constrained_pca(spectral_orders_matrix2.flux, deriv_2, rvs_ccf_gauss2)
   frac_var_explained2 = 1.0.-cumsum(principalvars(M2))./tvar(M2)
   println("# Fraction of variance explained = ", frac_var_explained2[1:min(5,length(frac_var_explained2))])
   if write_dcpca_to_csv
      using CSV
      CSV.write(joinpath(output_dir,target_subdir * "_dcpca_basis2.csv"),  Tables.table(M.proj) )
      CSV.write(joinpath(output_dir,target_subdir * "_dcpca_scores2.csv"), Tables.table(dcpca_out) )
   end
   has_computed_dcpca2 = true
end


if make_plots  # Ploting results from DCPCA
  using Plots
  # Set parameters for plotting analysis
  plt_order = 42
  plt_order_pix = 4500:5000
  plt = scatter(frac_var_explained, xlabel="Number of PCs", ylabel="Frac Variance Unexplained")
  display(plt)
end

if make_plots
  plt_line = 170
  RvSpectML.plot_basis_vectors(order_grids, f_mean, deriv, M.proj, idx_plt = spectral_orders_matrix.chunk_map[plt_line], num_basis=3 )
  #xlims!(5761.5,5766)
end

if make_plots
  RvSpectML.plot_basis_scores(order_list_timeseries.times, rvs_ccf_gauss, dcpca_out, num_basis=3 )
end

if make_plots
  RvSpectML.plot_basis_scores_cor( rvs_ccf_gauss, dcpca_out, num_basis=3)
end


has_loaded_data = false
 has_computed_ccfs = false
 has_computed_rvs = false
 has_computed_template = false
 has_computed_dcpca = false
 has_found_lines = false
