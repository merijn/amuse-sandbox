      module amuse_support
         implicit none
         character (len=4096) :: AMUSE_inlist_path
         character (len=4096) :: AMUSE_mesa_dir
         character (len=4096) :: AMUSE_local_data_dir ! Used for output starting_models
         character (len=4096) :: AMUSE_zamsfile = 'zams_z2m2_y28.data' ! Z=0.02, Y=0.28
         double precision :: AMUSE_initial_z = 0.02d0
         double precision :: AMUSE_initial_y = -1.0
         double precision :: AMUSE_min_timestep_stop_condition = 1.0d-6
         double precision :: AMUSE_mixing_length_ratio = 2.0d0
         double precision :: AMUSE_semi_convection_efficiency = 0.0d0
         character (len=32) :: AMUSE_RGB_wind_scheme = ''
         character (len=32) :: AMUSE_AGB_wind_scheme = ''
         double precision :: AMUSE_reimers_wind_efficiency = 0.5d0
         double precision :: AMUSE_blocker_wind_efficiency = 0.1d0
         double precision :: AMUSE_de_jager_wind_efficiency = 0.8d0
         double precision :: AMUSE_dutch_wind_efficiency = 0.8d0
         double precision :: AMUSE_van_Loon_wind_eta = 0.0d0
         double precision :: AMUSE_Kudritzki_wind_eta = 0.0d0
         double precision :: AMUSE_Nieuwenhuijzen_wind_eta = 0.0d0
         double precision :: AMUSE_Vink_wind_eta = 0.0d0
         double precision :: AMUSE_overshoot_f_all = 0

         double precision, allocatable :: target_times(:)
         integer :: number_of_particles ! Dead or alive...

         logical :: new_model_defined = .false.
         integer :: id_new_model

         logical :: debugging = .false.
         logical :: do_stabilize_new_stellar_model = .true.

         contains
         logical function evolve_failed(str, ierr, return_var, errorcode)
            character (len=*), intent(in) :: str
            integer, intent(in) :: ierr, errorcode
            integer, intent(out) :: return_var
            evolve_failed = (ierr /= 0)
            if (evolve_failed) then
               write(*, *) trim(str) // ' ierr', ierr
               return_var = errorcode
            endif
         end function evolve_failed
         
         ! Copy of 'ctrls_io - do_one_setup', except for directory changes
         subroutine amuse_star_setup(id, inlist, ierr)
            use ctrls_io
            use utils_lib
            character (len=*), intent(in) :: inlist
            integer, intent(in) :: id
            integer, intent(out) :: ierr
            type (star_info), pointer :: s
            include 'formats'
            call get_star_ptr(id, s, ierr)
            if (ierr /= 0) return
            call set_default_controls
            
            ! For AMUSE:
            log_directory = trim(AMUSE_local_data_dir) // '/LOGS'
            photo_directory = trim(AMUSE_local_data_dir) // '/photos'
            
            call read_controls(id, inlist, ierr)
            if (ierr /= 0) return
            if (len_trim(s% extra_terminal_output_file) == 0) return
            s% extra_terminal_iounit = alloc_iounit(ierr)
            if (ierr /= 0) then
               write(*,*) 'failed to allocate io unit for ' // trim(s% extra_terminal_output_file)
               return
            end if
            open(unit=s% extra_terminal_iounit, file=trim(s% extra_terminal_output_file), &
                  action='write', status='replace',iostat=ierr)
            if (ierr /= 0) then
               write(*,*) 'failed to open ' // trim(s% extra_terminal_output_file)
               call free_iounit(s% extra_terminal_iounit)
               return
            end if
         end subroutine amuse_star_setup
         
! General initializations, used by new_zams_star, new_prems_star, and new_star_from_file
         integer function amuse_new_particle(AMUSE_id, AMUSE_mass)
            use run_star_support, only: failed, do_read_star_job, id_from_read_star_job, &
               do_star_job_controls_before
            use star_lib, only: starlib_init, star_set_kap_and_eos_handles, &
               star_load_zams, show_log_description
            use star_def, only: star_info, get_star_ptr
            use se_support, only: se_startup
            use const_def, only: mesa_data_dir, mesa_dir
            implicit none
            integer, intent(out) :: AMUSE_id
            integer :: ierr
            double precision, intent(in) :: AMUSE_mass
            type (star_info), pointer :: s
            
            amuse_new_particle = -1
            call do_read_star_job(AMUSE_inlist_path, ierr)
            if (failed('do_read_star_job', ierr)) return
            
            ! Replace value of mesa_data_dir just read, with supplied path.
            mesa_dir = AMUSE_mesa_dir
            mesa_data_dir = AMUSE_local_data_dir
            
            ! already allocated by read_star_job
            AMUSE_id = id_from_read_star_job
            id_from_read_star_job = 0
            number_of_particles = AMUSE_id
            call get_star_ptr(AMUSE_id, s, ierr)
            if (failed('get_star_ptr', ierr)) return
            
            s% job% mesa_dir = AMUSE_mesa_dir
            
            call starlib_init(s, ierr) ! okay to do extra calls on this
            if (failed('star_init',ierr)) return
            
            call star_set_kap_and_eos_handles(AMUSE_id, ierr)
            if (failed('set_star_kap_and_eos_handles',ierr)) return
            
            call amuse_star_setup(AMUSE_id, AMUSE_inlist_path, ierr)
            if (failed('amuse_star_setup', ierr)) return
            
            if (len_trim(s% op_mono_data_path) == 0) &
               call get_environment_variable( &
                  "MESA_OP_MONO_DATA_PATH", s% op_mono_data_path)
            
            if (len_trim(s% op_mono_data_cache_filename) == 0) &
               call get_environment_variable( &
                  "MESA_OP_MONO_DATA_CACHE_FILENAME", s% op_mono_data_cache_filename)         
            
            ! Replace value of mass and metallicity just read, with supplied values.
            s% initial_mass = AMUSE_mass
            s% initial_z = AMUSE_initial_z
            s% initial_y = AMUSE_initial_y
            s% zams_filename = trim(AMUSE_zamsfile)
            s% min_timestep_limit = AMUSE_min_timestep_stop_condition
            s% mixing_length_alpha = AMUSE_mixing_length_ratio
            s% alpha_semiconvection = AMUSE_semi_convection_efficiency
            s% RGB_wind_scheme = trim(AMUSE_RGB_wind_scheme)
            s% AGB_wind_scheme = trim(AMUSE_AGB_wind_scheme)
            s% Reimers_wind_eta = AMUSE_reimers_wind_efficiency
            s% Blocker_wind_eta = AMUSE_blocker_wind_efficiency
            s% de_Jager_wind_eta = AMUSE_de_jager_wind_efficiency
            s% Dutch_wind_eta = AMUSE_dutch_wind_efficiency
            s% van_Loon_wind_eta = AMUSE_van_Loon_wind_eta
            s% Kudritzki_wind_eta = AMUSE_Kudritzki_wind_eta
            s% Nieuwenhuijzen_wind_eta = AMUSE_Nieuwenhuijzen_wind_eta
            s% Vink_wind_eta = AMUSE_Vink_wind_eta
            s% overshoot_f_above_nonburn = AMUSE_overshoot_f_all
            s% overshoot_f_below_nonburn = AMUSE_overshoot_f_all
            s% overshoot_f_above_burn_h = AMUSE_overshoot_f_all
            s% overshoot_f_below_burn_h = AMUSE_overshoot_f_all
            s% overshoot_f_above_burn_he = AMUSE_overshoot_f_all
            s% overshoot_f_below_burn_he = AMUSE_overshoot_f_all
            s% overshoot_f_above_burn_z = AMUSE_overshoot_f_all
            s% overshoot_f_below_burn_z = AMUSE_overshoot_f_all
            if (debugging) then
               write (*,*) "Creating new particles with mass: ", s% initial_mass
               write (*,*) "Loading starting model from: ", s% zams_filename
            endif
            if (s% job% show_log_description_at_start .and. AMUSE_id == 1) then
               write(*,*)
               call show_log_description(AMUSE_id, ierr)
               if (failed('show_log_description', ierr)) return
            end if
            write(*,*)
            
            call do_star_job_controls_before(AMUSE_id, s, .false., ierr)
            if (failed('do_star_job_controls_before', ierr)) return
            amuse_new_particle = 0
         end function amuse_new_particle
      
      end module amuse_support

! Set the paths to the inlist and the data directory
      integer function set_MESA_paths(AMUSE_inlist_path_in, &
            AMUSE_mesa_dir_in, AMUSE_local_data_dir_in)
         use amuse_support, only: AMUSE_inlist_path, &
            AMUSE_mesa_dir, AMUSE_local_data_dir
         implicit none
         character(*), intent(in) :: AMUSE_inlist_path_in, &
            AMUSE_mesa_dir_in, AMUSE_local_data_dir_in
         AMUSE_inlist_path = AMUSE_inlist_path_in
         AMUSE_mesa_dir = AMUSE_mesa_dir_in
         AMUSE_local_data_dir = AMUSE_local_data_dir_in
         set_MESA_paths = 0
      end function set_MESA_paths

! Initialize the stellar evolution code
      integer function initialize_code()
         implicit none
         initialize_code = 0
      end function initialize_code


      integer function commit_parameters()
         commit_parameters = 0
      end function commit_parameters

      integer function recommit_parameters()
         recommit_parameters = 0
      end function recommit_parameters

      integer function cleanup_code()
         cleanup_code = 0
      end function cleanup_code


      integer function new_zams_star(AMUSE_id, AMUSE_mass)
         use amuse_support, only: amuse_new_particle
         use run_star_support, only: failed, do_star_job_controls_after, before_evolve
         use star_lib, only: show_terminal_header, star_load_zams, start_new_run_for_pgstar
         use star_def, only: star_info, get_star_ptr
         use se_support, only: se_startup
         implicit none
         integer, intent(out) :: AMUSE_id
         integer :: ierr
         double precision, intent(in) :: AMUSE_mass
         type (star_info), pointer :: s
         
         new_zams_star = -1
         ierr = amuse_new_particle(AMUSE_id, AMUSE_mass)
         if (failed('amuse_new_particle', ierr)) return
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         
   !~         call do_load1_star(id, s, .false., 'restart_photo', ierr)
   !~         if (failed('do_load1_star',ierr)) return
         call star_load_zams(AMUSE_id, ierr)
         if (failed('star_load_zams', ierr)) return
            
         call do_star_job_controls_after(AMUSE_id, s, .false., ierr)
         if (failed('do_star_job_controls_after',ierr)) return
         
         write(*,*)
         write(*,*)
         call before_evolve(AMUSE_id, ierr)
         if (failed('before_evolve',ierr)) return
         call start_new_run_for_pgstar(s, ierr)
         if (failed('start_new_run_for_pgstar',ierr)) return
         call se_startup(s, AMUSE_id, .false., s% job% use_se_output, ierr)
         if (failed('se_startup',ierr)) return
         call show_terminal_header(AMUSE_id, ierr)
         if (failed('show_terminal_header', ierr)) return
         call flush()
         new_zams_star = 0
      end function new_zams_star

! Create a new pre-main-sequence star
      integer function new_prems_star(AMUSE_id, AMUSE_mass)
         use amuse_support, only: amuse_new_particle
         use run_star_support, only: failed, do_star_job_controls_after, before_evolve
         use star_lib, only: show_terminal_header, star_create_pre_ms_model, start_new_run_for_pgstar
         use star_def, only: star_info, get_star_ptr
         use se_support, only: se_startup
         implicit none
         integer, intent(out) :: AMUSE_id
         integer :: ierr
         double precision, intent(in) :: AMUSE_mass
         type (star_info), pointer :: s
         
         new_prems_star = -1
         ierr = amuse_new_particle(AMUSE_id, AMUSE_mass)
         if (failed('amuse_new_particle', ierr)) return
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         
         call star_create_pre_ms_model( &
            AMUSE_id, s% job% pre_ms_T_c, s% job% pre_ms_guess_rho_c, &
            s% job% pre_ms_d_log10_P, s% job% pre_ms_logT_surf_limit, &
            s% job% pre_ms_logP_surf_limit, &
            s% job% initial_zfracs, s% job% pre_ms_relax_num_steps, ierr)
         if (failed('star_create_pre_ms_model',ierr)) return
         
         call do_star_job_controls_after(AMUSE_id, s, .false., ierr)
         if (failed('do_star_job_controls_after',ierr)) return
         
         write(*,*)
         write(*,*)
         call before_evolve(AMUSE_id, ierr)
         if (failed('before_evolve',ierr)) return
         call start_new_run_for_pgstar(s, ierr)
         if (failed('start_new_run_for_pgstar',ierr)) return
         call se_startup(s, AMUSE_id, .false., s% job% use_se_output, ierr)
         if (failed('se_startup',ierr)) return
         call show_terminal_header(AMUSE_id, ierr)
         if (failed('show_terminal_header', ierr)) return
         call flush()
         new_prems_star = 0
      end function new_prems_star

! Create a new star from a saved model
      integer function new_star_from_file(AMUSE_id, AMUSE_filename)
         use amuse_support, only: amuse_new_particle
         use run_star_support, only: failed, do_star_job_controls_after, before_evolve
         use star_lib, only: show_terminal_header, star_read_model, start_new_run_for_pgstar
         use star_def, only: star_info, get_star_ptr
         use se_support, only: se_startup
         implicit none
         integer, intent(out) :: AMUSE_id
         integer :: ierr
         character(*), intent(in) :: AMUSE_filename
         type (star_info), pointer :: s
         
         new_star_from_file = -1
         ierr = amuse_new_particle(AMUSE_id, -1.0d0)
         if (failed('amuse_new_particle', ierr)) return
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         
         s% job% saved_model_name = trim(AMUSE_filename)
         call star_read_model(AMUSE_id, s% job% saved_model_name, ierr)
         if (failed('star_read_model',ierr)) return
         
         call do_star_job_controls_after(AMUSE_id, s, .false., ierr)
         if (failed('do_star_job_controls_after',ierr)) return
         
         write(*,*)
         write(*,*)
         call before_evolve(AMUSE_id, ierr)
         if (failed('before_evolve',ierr)) return
         call start_new_run_for_pgstar(s, ierr)
         if (failed('start_new_run_for_pgstar',ierr)) return
         call se_startup(s, AMUSE_id, .false., s% job% use_se_output, ierr)
         if (failed('se_startup',ierr)) return
         call show_terminal_header(AMUSE_id, ierr)
         if (failed('show_terminal_header', ierr)) return
         call flush()
         new_star_from_file = 0
      end function new_star_from_file

      integer function write_star_to_file(AMUSE_id, AMUSE_filename)
         use star_lib, only: star_write_model
         implicit none
         integer, intent(in) :: AMUSE_id
         character(*), intent(in) :: AMUSE_filename
         integer :: ierr
         call star_write_model(AMUSE_id, AMUSE_filename, ierr)
         write_star_to_file = ierr
      end function write_star_to_file

! Remove a particle (doesn't do anything yet)
      function delete_star(AMUSE_id)
         implicit none
         integer, intent(in) :: AMUSE_id
         integer :: delete_star
         delete_star = 0
      end function
   
      function commit_particles()
         use amuse_support, only: target_times, number_of_particles
         use star_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer :: commit_particles, k, ierr
         type (star_info), pointer :: s
         allocate(target_times(number_of_particles))
         do k = 1, number_of_particles
            call get_star_ptr(k, s, ierr)
            if (failed('get_star_ptr', ierr)) return
            target_times(k) = s% time
         end do
         commit_particles = 0
      end function
   
      function recommit_particles()
         use amuse_support, only: target_times, number_of_particles
         use star_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer :: recommit_particles, k, ierr
         type (star_info), pointer :: s
         double precision, allocatable :: temp(:)
         allocate(temp(size(target_times)))
         temp = target_times
         deallocate(target_times)
         allocate(target_times(number_of_particles))
         target_times = 0
         target_times(1:size(temp)) = temp
         do k = size(temp)+1, number_of_particles
            call get_star_ptr(k, s, ierr)
            if (failed('get_star_ptr', ierr)) return
            target_times(k) = s% time
         end do
         deallocate(temp)
         recommit_particles = 0
      end function

! Get/setters for code parameters:

! Return the number of particles currently allocated in the code
      function get_number_of_particles(AMUSE_value)
         implicit none
         integer :: get_number_of_particles
         integer, intent(out) :: AMUSE_value
         AMUSE_value = -1
         get_number_of_particles = -1
      end function

! Return the metallicity parameter
      integer function get_metallicity(AMUSE_value)
         use amuse_support, only: AMUSE_initial_z
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_initial_z
         get_metallicity = 0
      end function

! Set the metallicity parameter
      integer function set_metallicity(AMUSE_value)
         use amuse_support, only: AMUSE_initial_z
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_initial_z = AMUSE_value
         set_metallicity = 0
      end function
   
      integer function set_zamsfile(AMUSE_value)
         use amuse_support, only: AMUSE_zamsfile, AMUSE_local_data_dir
         use utils_lib, only: alloc_iounit, free_iounit
         use run_star_support, only: failed
         implicit none
         character(*), intent(in) :: AMUSE_value
         integer :: ierr, iounit
         character(len=4096) :: tmp
         set_zamsfile = -1
         ! Check whether the file exists
         iounit = alloc_iounit(ierr)
         if (failed('alloc_iounit', ierr)) return
         open(iounit, file=trim(AMUSE_value), action='read', status='old', iostat=ierr)
         if (ierr /= 0) then
            tmp = trim(AMUSE_local_data_dir) // '/star_data/zams_models/' // trim(AMUSE_value)
            open(iounit, file=trim(tmp), action='read', status='old', iostat=ierr)
            if (ierr /= 0) then
               write(*, *) 'Missing zams file: ', trim(AMUSE_value)
               write(*, *) 'Not found here, nor at: ', &
                  trim(AMUSE_local_data_dir), '/star_data/zams_models/'
               call free_iounit(iounit)
               return
            endif
         endif
         
         close(iounit)
         call free_iounit(iounit)
         AMUSE_zamsfile = AMUSE_value
         set_zamsfile = 0
      end function set_zamsfile
      
      integer function get_zamsfile(AMUSE_value)
         use amuse_support, only: AMUSE_zamsfile
         implicit none
         character(*), intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_zamsfile
         get_zamsfile = 0
      end function get_zamsfile

! Return the current mass of the star
   function get_mass(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(out) :: AMUSE_value
      integer :: get_mass, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1.0
         get_mass = -1
      else
         AMUSE_value = s% star_mass
         get_mass = 0
      endif
   end function
! Set the current mass of the star
   function set_mass(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use const_def, only: msol
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(in) :: AMUSE_value
      integer :: set_mass, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         set_mass = -1
      else
         s% mstar = AMUSE_value * msol
         s% mstar_old = AMUSE_value * msol
         s% mstar_older = AMUSE_value * msol
         s% star_mass = AMUSE_value
         set_mass = 0
      endif
   end function

! Return the current core mass of the star, where hydrogen abundance is <= h1_boundary_limit
   function get_core_mass(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(out) :: AMUSE_value
      integer :: get_core_mass, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1.0
         get_core_mass = -1
      else
         AMUSE_value = s% he_core_mass
         get_core_mass = 0
      endif
   end function

! Return the current mass loss rate of the star
   function get_mass_loss_rate(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(out) :: AMUSE_value
      integer :: get_mass_loss_rate, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1.0
         get_mass_loss_rate = -1
      else
         AMUSE_value = -s% mstar_dot
         get_mass_loss_rate = 0
      endif
   end function

! Return the current user-specified mass transfer rate of the star
   function get_manual_mass_transfer_rate(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(out) :: AMUSE_value
      integer :: get_manual_mass_transfer_rate, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1.0
         get_manual_mass_transfer_rate = -1
      else
         AMUSE_value = s% mass_change
         get_manual_mass_transfer_rate = 0
      endif
   end function

! Set a new user-specified mass transfer rate of the star
   function set_manual_mass_transfer_rate(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(out) :: AMUSE_value
      integer :: set_manual_mass_transfer_rate, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         set_manual_mass_transfer_rate = -1
      else
         s% mass_change = AMUSE_value
         set_manual_mass_transfer_rate = 0
      endif
   end function

! Return the current temperature of the star
   function get_temperature(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(out) :: AMUSE_value
      integer :: get_temperature, ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1.0
         get_temperature = -1
      else
         AMUSE_value = s% Teff
         get_temperature = 0
      endif
   end function

! Return the current luminosity of the star
      function get_luminosity(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(out) :: AMUSE_value
         integer :: get_luminosity, ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_luminosity = -1
         else
            AMUSE_value = 10.0d0**s% log_surface_luminosity
            get_luminosity = 0
         endif
      end function

! Return the current age of the star
      function get_age(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(out) :: AMUSE_value
         integer :: get_age, ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_age = -1
         else
            AMUSE_value = s% star_age
            get_age = 0
         endif
      end function

! Return the next timestep for the star
      function get_time_step(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use const_def, only: secyer
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(out) :: AMUSE_value
         integer :: get_time_step, ierr
         type (star_info), pointer :: s
         AMUSE_value = -1.0
         get_time_step = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         AMUSE_value = s% dt_next/secyer
         get_time_step = 0
      end function

! Set the next timestep for the star
      function set_time_step(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use const_def, only: secyer
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(in) :: AMUSE_value
         integer :: set_time_step, ierr
         type (star_info), pointer :: s
         set_time_step = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         s% dt_next = AMUSE_value*secyer
         set_time_step = 0
      end function

! if true, composition of accreted material is identical to the current surface composition.
      function get_accrete_same_as_surface(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(out) :: AMUSE_value
         integer :: get_accrete_same_as_surface, ierr
         type (star_info), pointer :: s
         get_accrete_same_as_surface = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         if (s% accrete_same_as_surface) then
            AMUSE_value = 1
         else
            AMUSE_value = 0
         endif
         get_accrete_same_as_surface = 0
      end function
      function set_accrete_same_as_surface(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(in) :: AMUSE_value
         integer :: set_accrete_same_as_surface, ierr
         type (star_info), pointer :: s
         set_accrete_same_as_surface = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         if (AMUSE_value > 0) then
            s% accrete_same_as_surface = .true.
         else
            s% accrete_same_as_surface = .false.
         endif
         set_accrete_same_as_surface = 0
      end function

! otherwise, then use the following parameters
      function get_accrete_composition_non_metals(AMUSE_id, h1, h2, he3, he4)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(out) :: h1, h2, he3, he4
         integer :: get_accrete_composition_non_metals, ierr
         type (star_info), pointer :: s
         get_accrete_composition_non_metals = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         h1 = s% accretion_h1
         h2 = s% accretion_h2
         he3 = s% accretion_he3
         he4 = s% accretion_he4
         get_accrete_composition_non_metals = 0
      end function
      function set_accrete_composition_non_metals(AMUSE_id, h1, h2, he3, he4)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(in) :: h1, h2, he3, he4
         integer :: set_accrete_composition_non_metals, ierr
         type (star_info), pointer :: s
         set_accrete_composition_non_metals = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         s% accretion_h1 = h1 ! mass fraction
         s% accretion_h2 = h2 ! if no h2 in current net, then this is automatically added to h1
         s% accretion_he3 = he3
         s% accretion_he4 = he4
         set_accrete_composition_non_metals = 0
      end function

! one of the identifiers for different Z fractions from chem_def
! AG89_zfracs = 1, Anders & Grevesse 1989
! GN93_zfracs = 2, Grevesse & Noels 1993
! GS98_zfracs = 3, Grevesse & Sauval 1998
! L03_zfracs = 4, Lodders 2003
! AGS04_zfracs = 5, Asplund, Grevesse & Sauval 2004
! or set accretion_zfracs = 0 to use special list of z fractions
      function get_accrete_composition_metals_identifier(AMUSE_id, zfracs_identifier)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(out) :: zfracs_identifier
         integer :: get_accrete_composition_metals_identifier, ierr
         type (star_info), pointer :: s
         get_accrete_composition_metals_identifier = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         zfracs_identifier = s% accretion_zfracs
         get_accrete_composition_metals_identifier = 0
      end function
      function set_accrete_composition_metals_identifier(AMUSE_id, zfracs_identifier)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(in) :: zfracs_identifier
         integer :: set_accrete_composition_metals_identifier, ierr
         type (star_info), pointer :: s
         set_accrete_composition_metals_identifier = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         if (zfracs_identifier > 5 .or. zfracs_identifier < 0) then

         endif
         s% accretion_zfracs = zfracs_identifier
         set_accrete_composition_metals_identifier = 0
      end function

! special list of z fractions -- if you use these, they should add to 1.0
      function get_accrete_composition_metals(AMUSE_id, li, be, b, c, n, o, f, ne, &
      na, mg, al, si, p, s, cl, ar, k, ca, sc, ti, v, cr, mn, fe, co, ni, cu, zn)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(out) :: li, be, b, c, n, o, f, ne, na, mg, al, si
         double precision, intent(out) :: p, s, cl, ar, k, ca, sc, ti, v, cr, mn
         double precision, intent(out) :: fe, co, ni, cu, zn
         integer :: get_accrete_composition_metals, ierr
         type (star_info), pointer :: star_pointer
         get_accrete_composition_metals = -1
         call get_star_ptr(AMUSE_id, star_pointer, ierr)
         if (failed('get_star_ptr', ierr)) return
         li = star_pointer% z_fraction_li
         be = star_pointer% z_fraction_be
         b = star_pointer% z_fraction_b
         c = star_pointer% z_fraction_c
         n = star_pointer% z_fraction_n
         o = star_pointer% z_fraction_o
         f = star_pointer% z_fraction_f
         ne = star_pointer% z_fraction_ne
         na = star_pointer% z_fraction_na
         mg = star_pointer% z_fraction_mg
         al = star_pointer% z_fraction_al
         si = star_pointer% z_fraction_si
         p = star_pointer% z_fraction_p
         s = star_pointer% z_fraction_s
         cl = star_pointer% z_fraction_cl
         ar = star_pointer% z_fraction_ar
         k = star_pointer% z_fraction_k
         ca = star_pointer% z_fraction_ca
         sc = star_pointer% z_fraction_sc
         ti = star_pointer% z_fraction_ti
         v = star_pointer% z_fraction_v
         cr = star_pointer% z_fraction_cr
         mn = star_pointer% z_fraction_mn
         fe = star_pointer% z_fraction_fe
         co = star_pointer% z_fraction_co
         ni = star_pointer% z_fraction_ni
         cu = star_pointer% z_fraction_cu
         zn = star_pointer% z_fraction_zn
         get_accrete_composition_metals = 0
      end function
      function set_accrete_composition_metals(AMUSE_id, li, be, b, c, n, o, f, ne, &
      na, mg, al, si, p, s, cl, ar, k, ca, sc, ti, v, cr, mn, fe, co, ni, cu, zn)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(in) :: li, be, b, c, n, o, f, ne, na, mg, al, si
         double precision, intent(in) :: p, s, cl, ar, k, ca, sc, ti, v, cr, mn
         double precision, intent(in) :: fe, co, ni, cu, zn
         integer :: set_accrete_composition_metals, ierr
         type (star_info), pointer :: star_pointer
         set_accrete_composition_metals = -1
         call get_star_ptr(AMUSE_id, star_pointer, ierr)
         if (failed('get_star_ptr', ierr)) return
         star_pointer% z_fraction_li = li
         star_pointer% z_fraction_be = be
         star_pointer% z_fraction_b = b
         star_pointer% z_fraction_c = c
         star_pointer% z_fraction_n = n
         star_pointer% z_fraction_o = o
         star_pointer% z_fraction_f = f
         star_pointer% z_fraction_ne = ne
         star_pointer% z_fraction_na = na
         star_pointer% z_fraction_mg = mg
         star_pointer% z_fraction_al = al
         star_pointer% z_fraction_si = si
         star_pointer% z_fraction_p = p
         star_pointer% z_fraction_s = s
         star_pointer% z_fraction_cl = cl
         star_pointer% z_fraction_ar = ar
         star_pointer% z_fraction_k = k
         star_pointer% z_fraction_ca = ca
         star_pointer% z_fraction_sc = sc
         star_pointer% z_fraction_ti = ti
         star_pointer% z_fraction_v = v
         star_pointer% z_fraction_cr = cr
         star_pointer% z_fraction_mn = mn
         star_pointer% z_fraction_fe = fe
         star_pointer% z_fraction_co = co
         star_pointer% z_fraction_ni = ni
         star_pointer% z_fraction_cu = cu
         star_pointer% z_fraction_zn = zn
         set_accrete_composition_metals = 0
      end function

! Return the current radius of the star
      function get_radius(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         double precision, intent(out) :: AMUSE_value
         integer :: get_radius, ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_radius = -1
         else
            AMUSE_value = 10.0d0**s% log_surface_radius
            get_radius = 0
         endif
      end function

! Return the current stellar type of the star
      function get_stellar_type(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         use do_one_utils, only: do_show_terminal_header, do_terminal_summary
         use star_utils, only:eval_current_y, eval_current_z
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(out) :: AMUSE_value
         integer :: get_stellar_type, ierr
         double precision :: x_avg, y_avg, z_avg
         type (star_info), pointer :: s
         AMUSE_value = -99
         get_stellar_type = -1
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) return
         ! if the star is not a stellar remnant...
         if (s% log_surface_radius > -1.0) then
            ! Use the MESA phase_of_evolution marker (explained below)
            select case(s% phase_of_evolution)
               case(0)
                  AMUSE_value = 17 ! Pre-main-sequence star
               case(1,2)
                  if (s% star_mass < 0.75) then
                     AMUSE_value = 0 ! Convective low mass star
                  else
                     AMUSE_value = 1 ! Main sequence star
                  endif
               case(3)
                  AMUSE_value = 3 ! Red giant branch
               case(4:)
                  y_avg = eval_current_y(s, 1, s% nz, ierr)
                  if (failed('eval_current_y', ierr)) return
                  z_avg = eval_current_z(s, 1, s% nz, ierr)
                  if (failed('eval_current_z', ierr)) return
                  x_avg = max(0d0, min(1d0, 1 - (y_avg + z_avg)))
                  if (x_avg > 1.0d-5) then
                     if (s% center_he3 + s% center_he4 > 1.0d-5) then
                        AMUSE_value = 4 ! Core He burning
                     else
                        if (y_avg < 0.75 * x_avg) then
                           AMUSE_value = 5 ! Early AGB (inert C/O core)
                        else
                           AMUSE_value = 6 ! Late (thermally pulsing) AGB (inert C/O core)
                        endif
                     endif
                  else
                     if (s% center_he3 + s% center_he4 > 1.0d-5) then
                        AMUSE_value = 7 ! Helium MS star
                     else
                        AMUSE_value = 9 ! Helium giant
                     endif
                  endif
               case default
                  write(*,*) "Unable to determine the stellar type."
                  write(*,*) "The following information might help:"
                  call do_show_terminal_header(s)
                  call do_terminal_summary(s)
                  return
            end select
         else ! stellar remnant
            if (s% star_mass < 1.44) then ! white dwarf
               ! Helium White Dwarf:
               if (s% center_he3 + s% center_he4 > 0.1) AMUSE_value = 10
               ! Carbon/Oxygen White Dwarf:
               if (s% center_c12 > 0.1) AMUSE_value = 11
               ! Oxygen/Neon White Dwarf:
               if (s% center_ne20 > 0.01) AMUSE_value = 12
                ! Else? Unknown kind of white dwarf... hopefully never reached.
               if (AMUSE_value == -99) AMUSE_value = -10
            else
               if (s% star_mass < 3.2) then
                  AMUSE_value = 13 ! Neutron Star
               else
                  AMUSE_value = 14 ! Black Hole
               endif
            endif
         endif
         get_stellar_type = 0
!      integer, parameter :: phase_starting = 0
!      integer, parameter :: phase_early_main_seq = 1
!      integer, parameter :: phase_mid_main_seq = 2
!      integer, parameter :: phase_wait_for_he = 3
!      integer, parameter :: phase_he_ignition_over = 4
!      integer, parameter :: phase_he_igniting = 5
!      integer, parameter :: phase_helium_burning = 6
!      integer, parameter :: phase_carbon_burning = 7
      end function

! Return the current number of zones/mesh-cells of the star
      integer function get_number_of_zones(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1
            get_number_of_zones = -1
         else
            AMUSE_value = s% nz
            get_number_of_zones = 0
         endif
      end function

! Return the number_of_backups_in_a_row of the star
      integer function get_number_of_backups_in_a_row(AMUSE_id, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            get_number_of_backups_in_a_row = -1
         else
            AMUSE_value = s% number_of_backups_in_a_row
            get_number_of_backups_in_a_row = 0
         endif
      end function

!~! Reset number_of_backups_in_a_row of the star
      integer function reset_number_of_backups_in_a_row(AMUSE_id)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            reset_number_of_backups_in_a_row = -1
         else
            s% number_of_backups_in_a_row = 0
            reset_number_of_backups_in_a_row = 0
         endif
      end function

! Return the mass fraction at the specified zone/mesh-cell of the star
      integer function get_mass_fraction_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_mass_fraction_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_mass_fraction_at_zone = -2
            else
               if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
                  AMUSE_value = s% dq_old(s% nz - AMUSE_zone)
               else
                  AMUSE_value = s% dq(s% nz - AMUSE_zone)
               endif
               get_mass_fraction_at_zone = 0
            endif
         endif
      end function
! Set the mass fraction at the specified zone/mesh-cell of the star
      integer function set_mass_fraction_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(in) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            set_mass_fraction_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
               set_mass_fraction_at_zone = -2
            else
               s% dq(s% nz - AMUSE_zone) = AMUSE_value
               set_mass_fraction_at_zone = 0
            endif
         endif
      end function

! Return the temperature at the specified zone/mesh-cell of the star
      integer function get_temperature_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_temperature_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_temperature_at_zone = -2
            else
               if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
                  AMUSE_value = exp(s% xh_old(s% i_lnT, s% nz - AMUSE_zone))
               else
                  AMUSE_value = exp(s% xh(s% i_lnT, s% nz - AMUSE_zone))
               endif
               get_temperature_at_zone = 0
            endif
         endif
      end function

! Return the density at the specified zone/mesh-cell of the star
      integer function get_density_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_density_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
               AMUSE_value = -1.0
               get_density_at_zone = -2
            else
               if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
                  AMUSE_value = exp(s% xh_old(s% i_xlnd, s% nz - AMUSE_zone))
               else
                  AMUSE_value = exp(s% xh(s% i_xlnd, s% nz - AMUSE_zone))
               endif
               get_density_at_zone = 0
            endif
         endif
      end function

! Return the radius at the specified zone/mesh-cell of the star
      integer function get_radius_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_radius_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_radius_at_zone = -2
            else
               if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
                  AMUSE_value = exp(s% xh_old(s% i_lnR, s% nz - AMUSE_zone))
               else
                  AMUSE_value = exp(s% xh(s% i_lnR, s% nz - AMUSE_zone))
               endif
               get_radius_at_zone = 0
            endif
         endif
      end function

! Return the luminosity at the specified zone/mesh-cell of the star
      integer function get_luminosity_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_luminosity_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_luminosity_at_zone = -2
            else
               if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
                  AMUSE_value = s% xh_old(s% i_lum, s% nz - AMUSE_zone)
               else
                  AMUSE_value = s% xh(s% i_lum, s% nz - AMUSE_zone)
               endif
               get_luminosity_at_zone = 0
            endif
         endif
      end function
! Set the luminosity at the specified zone/mesh-cell of the star
      integer function set_luminosity_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(in) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            set_luminosity_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
               set_luminosity_at_zone = -2
            else
               s% xh(s% i_lum, s% nz - AMUSE_zone) = AMUSE_value
               set_luminosity_at_zone = 0
            endif
         endif
      end function

! Return the Brunt-Vaisala frequency squared at the specified zone/mesh-cell of the star
      integer function get_brunt_vaisala_frequency_squared_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_brunt_vaisala_frequency_squared_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_brunt_vaisala_frequency_squared_at_zone = -2
            else
                AMUSE_value = s% brunt_N2(s% nz - AMUSE_zone)
               get_brunt_vaisala_frequency_squared_at_zone = 0
            endif
         endif
      end function

! Return the mean molecular weight per particle (ions + free electrons) at the specified zone/mesh-cell of the star
      integer function get_mu_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_mu_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_mu_at_zone = -2
            else
                AMUSE_value = s% mu(s% nz - AMUSE_zone)
               get_mu_at_zone = 0
            endif
         endif
      end function

! Return the total (gas + radiation) pressure at the specified zone/mesh-cell of the star
      integer function get_pressure_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr
         type (star_info), pointer :: s
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_pressure_at_zone = -1
         else
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_pressure_at_zone = -2
            else
               AMUSE_value = s% P(s% nz - AMUSE_zone)
               get_pressure_at_zone = 0
            endif
         endif
      end function

! Return the specific entropy at the specified zone/mesh-cell of the star
      integer function get_entropy_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         use amuse_support, only: debugging
         
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr, k
         type (star_info), pointer :: s
         
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_entropy_at_zone = -1
         else
            k = s% nz - AMUSE_zone
            if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
               get_entropy_at_zone = -1
               return
            endif
            
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_entropy_at_zone = -2
            else
               AMUSE_value = exp(s% lnS(k))
               get_entropy_at_zone = 0
            endif
         endif         
      end function

! Return the specific thermal energy at the specified zone/mesh-cell of the star
      integer function get_thermal_energy_at_zone(AMUSE_id, AMUSE_zone, AMUSE_value)
         use star_private_def, only: star_info, get_star_ptr
         use run_star_support, only: failed
         use amuse_support, only: debugging
         
         implicit none
         integer, intent(in) :: AMUSE_id, AMUSE_zone
         double precision, intent(out) :: AMUSE_value
         integer :: ierr, k
         type (star_info), pointer :: s
         
         call get_star_ptr(AMUSE_id, s, ierr)
         if (failed('get_star_ptr', ierr)) then
            AMUSE_value = -1.0
            get_thermal_energy_at_zone = -1
         else
            k = s% nz - AMUSE_zone
            if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
               get_thermal_energy_at_zone = -1
               return
            endif
            
            if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
                AMUSE_value = -1.0
                get_thermal_energy_at_zone = -2
            else
               AMUSE_value = exp(s% lnE(k))
               get_thermal_energy_at_zone = 0
            endif
         endif         
      end function



! Return the current number of chemical abundance variables per zone of the star
   integer function get_number_of_species(AMUSE_id, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      integer, intent(out) :: AMUSE_value
      integer :: ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1
         get_number_of_species = -1
      else
         AMUSE_value = s% nvar_chem
         get_number_of_species = 0
      endif
   end function

! Return the name of chemical abundance variable 'AMUSE_species' of the star
   integer function get_name_of_species(AMUSE_id, AMUSE_species, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      use chem_def, only: num_chem_isos, chem_isos
      implicit none
      integer, intent(in) :: AMUSE_id, AMUSE_species
      character (len=6), intent(out) :: AMUSE_value
      integer :: ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = 'error'
         get_name_of_species = -1
      else if (AMUSE_species > s% nvar_chem .or. AMUSE_species < 1) then
         AMUSE_value = 'error'
         get_name_of_species = -3
      else
         AMUSE_value = chem_isos% name(s% chem_id(AMUSE_species))
         get_name_of_species = 0
      endif
!      do ierr=1,s% nvar
!         write(*,*) ierr, s% nameofvar(ierr)
!      end do
!      do ierr=1,num_chem_isos
!         write(*,*) ierr, s% net_iso(ierr), chem_isos% name(ierr)
!      end do
!      do ierr=1,s% nvar_chem
!         write(*,*) ierr, s% chem_id(ierr), chem_isos% name(s% chem_id(ierr))
!      end do
   end function

! Return the mass fraction of species 'AMUSE_species' at the specified
! zone/mesh-cell of the star
   integer function get_mass_fraction_of_species_at_zone(AMUSE_id, &
         AMUSE_species, AMUSE_zone, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id, AMUSE_zone, AMUSE_species
      double precision, intent(out) :: AMUSE_value
      integer :: ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         AMUSE_value = -1.0
         get_mass_fraction_of_species_at_zone = -1
      else if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
         AMUSE_value = -1.0
         get_mass_fraction_of_species_at_zone = -2
      else if (AMUSE_species > s% nvar_chem .or. AMUSE_species < 1) then
         AMUSE_value = -1.0
         get_mass_fraction_of_species_at_zone = -3
      else
         if (s% number_of_backups_in_a_row > s% max_backups_in_a_row ) then
            AMUSE_value = s% xa_old(AMUSE_species, s% nz - AMUSE_zone)
         else
            AMUSE_value = s% xa(AMUSE_species, s% nz - AMUSE_zone)
         endif
         get_mass_fraction_of_species_at_zone = 0
      endif
   end function

! Set the mass fraction of species 'AMUSE_species' at the specified
! zone/mesh-cell of the star
   integer function set_mass_fraction_of_species_at_zone(AMUSE_id, &
         AMUSE_species, AMUSE_zone, AMUSE_value)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id, AMUSE_zone, AMUSE_species
      double precision, intent(in) :: AMUSE_value
      integer :: ierr
      type (star_info), pointer :: s
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) then
         set_mass_fraction_of_species_at_zone = -1
      else if (AMUSE_zone >= s% nz .or. AMUSE_zone < 0) then
         set_mass_fraction_of_species_at_zone = -2
      else if (AMUSE_species > s% nvar_chem .or. AMUSE_species < 1) then
         set_mass_fraction_of_species_at_zone = -3
      else
         s% xa(AMUSE_species, s% nz - AMUSE_zone) = AMUSE_value
         s% xa_pre(AMUSE_species, s% nz - AMUSE_zone) = AMUSE_value
         set_mass_fraction_of_species_at_zone = 0
      endif
   end function

! Erase memory of the star - xh_old(er), xa_old(er), q_old(er), etc.
! Useful after setting the stucture of the star, to prevent backup steps to undo changes
   integer function erase_memory(AMUSE_id)
      use star_private_def, only: star_info, get_star_ptr
      use run_star_support, only: failed
      implicit none
      integer, intent(in) :: AMUSE_id
      integer :: ierr
      type (star_info), pointer :: s

      erase_memory = -1
      call get_star_ptr(AMUSE_id, s, ierr)
      if (failed('get_star_ptr', ierr)) return
      if (s%generations > 1) then
         s% nz_old = s% nz
         call realloc2d_if_necessary(s% xa_old, s% species, s% nz, ierr)
         if (failed('realloc2d_if_necessary', ierr)) return
         s% xa_old(:,:) = s% xa(:,:)
         call realloc2d_if_necessary(s% xh_old, s% nvar, s% nz, ierr)
         if (failed('realloc2d_if_necessary', ierr)) return
         s% xh_old(:,:) = s% xh(:,:)
         call realloc1d_if_necessary(s% q_old, s% nz, ierr)
         if (failed('realloc1d_if_necessary', ierr)) return
         s% q_old(:) = s% q(:)
         call realloc1d_if_necessary(s% dq_old, s% nz, ierr)
         if (failed('realloc1d_if_necessary', ierr)) return
         s% dq_old(:) = s% dq(:)
         if (s%generations == 3) then
            s% nz_older = s% nz
            call realloc2d_if_necessary(s% xa_older, s% species, s% nz, ierr)
            if (failed('realloc2d_if_necessary', ierr)) return
            s% xa_older(:,:) = s% xa(:,:)
            call realloc2d_if_necessary(s% xh_older, s% nvar, s% nz, ierr)
            if (failed('realloc2d_if_necessary', ierr)) return
            s% xh_older(:,:) = s% xh(:,:)
            call realloc1d_if_necessary(s% q_older, s% nz, ierr)
            if (failed('realloc1d_if_necessary', ierr)) return
            s% q_older(:) = s% q(:)
            call realloc1d_if_necessary(s% dq_older, s% nz, ierr)
            if (failed('realloc1d_if_necessary', ierr)) return
            s% dq_older(:) = s% dq(:)
         end if
      end if
      erase_memory = 0

      contains

      subroutine realloc1d_if_necessary(ptr,new_size,ierr)
         double precision, pointer :: ptr(:)
         integer, intent(in) :: new_size
         integer, intent(out) :: ierr
         ierr = 0
         if (associated(ptr)) then
            if (size(ptr,1) == new_size) return
            deallocate(ptr)
         end if
         allocate(ptr(new_size),stat=ierr)
      end subroutine realloc1d_if_necessary

      subroutine realloc2d_if_necessary(ptr,ld,new_size,ierr)
         double precision, pointer :: ptr(:,:)
         integer, intent(in) :: ld, new_size
         integer, intent(out) :: ierr
         ierr = 0
         if (associated(ptr)) then
            if (size(ptr,1) == ld .and. size(ptr,2) == new_size) return
            deallocate(ptr)
         end if
         allocate(ptr(ld,new_size),stat=ierr)
      end subroutine realloc2d_if_necessary

   end function erase_memory

! Evolve the star for one step (for internal calls)
   function do_evolve_one_step(AMUSE_id)
      use star_lib
      use star_def, only: star_info, get_star_ptr, maxlen_history_column_name
      use run_star_support
      use amuse_support, only: evolve_failed
      use const_def, only: secyer
      use se_support, only: se_finish_step
      implicit none
      integer, intent(in) :: AMUSE_id
      integer :: do_evolve_one_step
      type (star_info), pointer :: s
      integer :: ierr, model_number, result, result_reason, id_extra, k, nz
      logical :: first_try, just_did_backup, successful_step
      real(dp) :: gamma1_integral, integral_norm
      
      1 format(a35, 99(1pe26.16))
      2 format(a35, i7, 1pe26.16)
      
      do_evolve_one_step = -1
      successful_step = .false.
      call get_star_ptr(AMUSE_id, s, ierr)
      if (evolve_failed('get_star_ptr', ierr, do_evolve_one_step, -1)) return
      
      s% result_reason = result_reason_normal
      
      if (s% use_other_adjust_net) then
         call s% other_adjust_net(s% id, ierr)
         if (failed('other_adjust_net',ierr)) return
      end if
      
      if (s% job% enable_adaptive_network) then
         call star_adjust_net(s% id, &
            s% job% min_x_for_keep, &
            s% job% min_x_for_n, &
            s% job% min_x_for_add, &
            ierr)
         if (failed('star_adjust_net',ierr)) return
      end if
      
      if (s% job% auto_extend_net) then
         call extend_net(s, ierr)
         if (failed('extend_net',ierr)) return
      end if
      
      if (s% center_ye <= s% job% center_ye_limit_for_v_flag &
            .and. .not. s% v_flag) then
         write(*,1) 'have reached center ye limit', &
            s% center_ye, s% job% center_ye_limit_for_v_flag
         write(*,1) 'set v_flag true'
         call star_set_v_flag(AMUSE_id, .true., ierr)
         if (failed('star_set_v_flag',ierr)) return
         if (ierr /= 0) return
      end if
      
      if (s% log_center_temperature > 9d0 .and. .not. s% v_flag) then 
         ! thanks go to Roni Waldman for this
         gamma1_integral = 0
         integral_norm = 0
         do k=1,s% nz
            integral_norm = integral_norm + s% P(k)*s% dm(k)/s% rho(k)
            gamma1_integral = gamma1_integral + &
               (s% gamma1(k)-4.d0/3.d0)*s% P(k)*s% dm(k)/s% rho(k)
         end do
         gamma1_integral = gamma1_integral/max(1d-99,integral_norm)
         if (gamma1_integral <= s% job% gamma1_integral_for_v_flag) then
            write(*,1) 'have reached gamma1 integral limit', gamma1_integral
            write(*,1) 'set v_flag true'
            call star_set_v_flag(AMUSE_id, .true., ierr)
            if (failed('star_set_v_flag',ierr)) return
            if (ierr /= 0) return
         end if
      end if
   
      if (s% job% report_mass_not_fe56) call do_report_mass_not_fe56(s)
      if (s% job% report_cell_for_xm > 0) call do_report_cell_for_xm(s)
   
      first_try = .true.
      just_did_backup = .false.
      
      model_number = get_model_number(AMUSE_id, ierr)
      if (failed('get_model_number',ierr)) return
      
      step_loop: do ! may need to repeat this loop
      
         result = star_evolve_step(AMUSE_id, first_try, just_did_backup)
         if (result == keep_going) result = star_check_model(AMUSE_id)
!~            if (result == keep_going) result = extras_check_model(s, AMUSE_id, id_extra)
         if (result == keep_going) result = star_pick_next_timestep(AMUSE_id)            
         if (result == keep_going) exit step_loop
         
         model_number = get_model_number(AMUSE_id, ierr)
         if (failed('get_model_number',ierr)) return
                        
         if (result == retry .and. s% job% report_retries) then
            write(*,'(i6,3x,a,/)') model_number, &
               'retry reason ' // trim(result_reason_str(s% result_reason))
         else if (result == backup .and. s% job% report_backups) then
            write(*,'(i6,3x,a,/)') model_number, &
               'backup reason ' // trim(result_reason_str(s% result_reason))
         end if
         
         if (result == redo) then
            result = star_prepare_to_redo(AMUSE_id)
         end if
         if (result == retry) then
            result = star_prepare_to_retry(AMUSE_id)
         end if
         if (result == backup) then
            result = star_do1_backup(AMUSE_id)
            just_did_backup = .true.
         else
            just_did_backup = .false.
         end if
         if (result == terminate) then
            exit step_loop
         end if
         first_try = .false.
         
      end do step_loop
      
      ! once we get here, the only options are keep_going or terminate.
      ! redo, retry, or backup must be done inside the step_loop
      
      if (result == keep_going) then              
         call adjust_tau_factor(s)
         if (s% L_nuc_burn_total/s% L_phot >= s% Lnuc_div_L_zams_limit &
               .and. .not. s% rotation_flag) then  
            call do_rotation_near_zams(s,ierr)
            if (ierr /= 0) return
         end if           
         if (s% rotation_flag) then      
            call do_rotation(s,ierr)
            if (ierr /= 0) return
         end if 
         ! if you have data that needs to be saved and restored for restarts, 
         ! save it in s% extra_iwork and s% extra_work
         ! before calling star_finish_step
         if (s% job% pgstar_flag) call read_pgstar_controls(s, ierr) 
            ! do this before call extras_finish_step
         if (failed('read_pgstar_controls',ierr)) return
!~            result = extras_finish_step(s, AMUSE_id, id_extra)               
      end if
      
      if (result == keep_going) then
         result = se_finish_step(s, AMUSE_id, s% job% use_se_output, &
            how_many_extra_history_columns, data_for_extra_history_columns, &
            how_many_extra_profile_columns, data_for_extra_profile_columns)
      end if
      
      if (result == keep_going) then
         result = star_finish_step(AMUSE_id, id_extra, .false., &
            how_many_extra_profile_columns, data_for_extra_profile_columns, &
            how_many_extra_history_columns, data_for_extra_history_columns, ierr)
         if (failed('star_finish_step',ierr)) return
      end if
      
      if (result /= keep_going) then
         if (result /= terminate) then
            write(*,2) 'ERROR in result value in run_star_extras: model', &
               s% model_number
            write(*,2) 'result', result
         else
            if (s% result_reason == result_reason_normal) then
               result = star_pick_next_timestep(AMUSE_id) ! for saved model if any  
               result = se_finish_step(s, AMUSE_id, s% job% use_se_output, &
                  how_many_extra_history_columns, data_for_extra_history_columns, &
                  how_many_extra_profile_columns, data_for_extra_profile_columns)
               call save_profile(AMUSE_id, id_extra, &
                  how_many_extra_profile_columns, data_for_extra_profile_columns, &
                  3, ierr)
               s% need_to_save_profiles_now = .false.
               s% need_to_update_history_now = .true.
               result = star_finish_step( &
                  AMUSE_id, id_extra, s% job% save_photo_when_terminate, &
                  how_many_extra_profile_columns, data_for_extra_profile_columns, &
                  how_many_extra_history_columns, data_for_extra_history_columns, ierr)
               if (failed('star_finish_step',ierr)) return
               if (s% job% save_model_when_terminate) &
                  s% job% save_model_number = s% model_number                  
               if (s% job% save_pulsation_info_when_terminate) &
                  s% job% save_pulsation_info_for_model_number = s% model_number
               if (s% job% write_profile_when_terminate .and. &
                     len_trim(s% job% filename_for_profile_when_terminate) > 0) then
                  call star_write_profile_info( &
                     AMUSE_id, s% job% filename_for_profile_when_terminate, id_extra, &
                     how_many_extra_profile_columns, data_for_extra_profile_columns, ierr)
                  if (failed('star_write_profile_info',ierr)) return
               end if
               call do_saves( &
                  AMUSE_id, id_extra, s, &
                  how_many_extra_history_columns, &
                  data_for_extra_history_columns, &
                  how_many_extra_profile_columns, &
                  data_for_extra_profile_columns)
            end if
         end if
      else
         successful_step = .true.
      end if

      if (s% result_reason /= result_reason_normal) then
         write(*, *) 
         write(*, '(a)') 'terminated evolution: ' // &
            trim(result_reason_str(s% result_reason))
         write(*, *)
      end if
      
      if (s% termination_code > 0 .and. s% termination_code <= num_termination_codes) then
         write(*, '(a)') 'termination code: ' // &
            trim(termination_code_str(s% termination_code))
      end if
      
      call flush()
      if (successful_step) do_evolve_one_step = 0
      
      contains
      
      integer function how_many_extra_history_columns(s, id, id_extra)
         type (star_info), pointer :: s
         integer, intent(in) :: id, id_extra
         how_many_extra_history_columns = 0
      end function how_many_extra_history_columns
      
      
      subroutine data_for_extra_history_columns(s, id, id_extra, n, names, vals, ierr)
         type (star_info), pointer :: s
         integer, intent(in) :: id, id_extra, n
         character (len=maxlen_history_column_name) :: names(n)
         real(dp) :: vals(n)
         integer, intent(out) :: ierr
         ierr = 0
      end subroutine data_for_extra_history_columns

      
      integer function how_many_extra_profile_columns(s, id, id_extra)
         type (star_info), pointer :: s
         integer, intent(in) :: id, id_extra
         how_many_extra_profile_columns = 0
      end function how_many_extra_profile_columns
      
      
      subroutine data_for_extra_profile_columns(s, id, id_extra, n, nz, names, vals, ierr)
         type (star_info), pointer :: s
         integer, intent(in) :: id, id_extra, n, nz
         character (len=maxlen_history_column_name) :: names(n)
         real(dp) :: vals(nz,n)
         integer, intent(out) :: ierr
         integer :: k
         ierr = 0
      end subroutine data_for_extra_profile_columns
   
   end function do_evolve_one_step


! Evolve the star for one step (for calls from amuse)
   function evolve_one_step(AMUSE_id)
      use star_private_def, only: star_info, get_star_ptr
!      use const_def, only: secyer
      use amuse_support, only: evolve_failed, target_times
      implicit none
      integer, intent(in) :: AMUSE_id
      type (star_info), pointer :: s
      integer :: ierr, evolve_one_step
      integer :: do_evolve_one_step

      evolve_one_step = 0
      call get_star_ptr(AMUSE_id, s, ierr)
      if (evolve_failed('get_star_ptr', ierr, evolve_one_step, -1)) return

      evolve_one_step = do_evolve_one_step(AMUSE_id)
      target_times(AMUSE_id) = s% time
   end function evolve_one_step

! Evolve the star until AMUSE_end_time
   integer function evolve_for(AMUSE_id, AMUSE_delta_t)
      use star_private_def, only: star_info, get_star_ptr
      use const_def, only: secyer
      use amuse_support, only: evolve_failed, target_times
      implicit none
      integer, intent(in) :: AMUSE_id
      double precision, intent(in) :: AMUSE_delta_t
      type (star_info), pointer :: s
      integer :: ierr
      integer :: do_evolve_one_step

      evolve_for = 0
      call get_star_ptr(AMUSE_id, s, ierr)
      if (evolve_failed('get_star_ptr', ierr, evolve_for, -1)) return

      target_times(AMUSE_id) = target_times(AMUSE_id) + AMUSE_delta_t * secyer

      evolve_loop: do while(evolve_for == 0 .and. &
            (s% time + s% min_timestep_limit < target_times(AMUSE_id))) ! evolve one step per loop
         evolve_for = do_evolve_one_step(AMUSE_id)
      end do evolve_loop
   end function evolve_for

!~! Return the maximum age stop condition
!~      integer function get_max_age_stop_condition(AMUSE_value)
!~         use amuse_support, only: AMUSE_max_age_stop_condition
!~         implicit none
!~         double precision, intent(out) :: AMUSE_value
!~         AMUSE_value = AMUSE_max_age_stop_condition
!~         get_max_age_stop_condition = 0
!~      end function get_max_age_stop_condition
!~
!~! Set the maximum age stop condition
!~      integer function set_max_age_stop_condition(AMUSE_value)
!~         use amuse_support, only: AMUSE_max_age_stop_condition
!~         implicit none
!~         double precision, intent(in) :: AMUSE_value
!~         AMUSE_max_age_stop_condition = AMUSE_value
!~         set_max_age_stop_condition = 0
!~      end function set_max_age_stop_condition
!~
!~! Return the maximum age stop condition
!~      integer function get_max_iter_stop_condition(AMUSE_value)
!~         use amuse_support, only: AMUSE_max_iter_stop_condition
!~         implicit none
!~         integer, intent(out) :: AMUSE_value
!~         AMUSE_value = AMUSE_max_iter_stop_condition
!~         get_max_iter_stop_condition = 0
!~      end function get_max_iter_stop_condition
!~
!~! Set the maximum age stop condition
!~      integer function set_max_iter_stop_condition(AMUSE_value)
!~         use amuse_support, only: AMUSE_max_iter_stop_condition
!~         implicit none
!~         integer, intent(in) :: AMUSE_value
!~         AMUSE_max_iter_stop_condition = AMUSE_value
!~         set_max_iter_stop_condition = 0
!~      end function set_max_iter_stop_condition

! Return the minimum timestep stop condition
      integer function get_min_timestep_stop_condition(AMUSE_value)
         use amuse_support, only: AMUSE_min_timestep_stop_condition
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_min_timestep_stop_condition
         get_min_timestep_stop_condition = 0
      end function get_min_timestep_stop_condition

! Set the minimum timestep stop condition
      integer function set_min_timestep_stop_condition(AMUSE_value)
         use amuse_support, only: AMUSE_min_timestep_stop_condition
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_min_timestep_stop_condition = AMUSE_value
         set_min_timestep_stop_condition = 0
      end function set_min_timestep_stop_condition


      logical function is_valid_wind_scheme(AMUSE_value)
         implicit none
         character(*), intent(in) :: AMUSE_value
         if (len(trim(AMUSE_value)) == 0) then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'Reimers') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'Blocker') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'de Jager') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'van Loon') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'Nieuwenhuijzen') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'Kudritzki') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'Vink') then
            is_valid_wind_scheme = .true.
         else if (trim(AMUSE_value) == 'Dutch') then
            is_valid_wind_scheme = .true.
         else
            is_valid_wind_scheme = .false.
         endif
      end function is_valid_wind_scheme

! Return the wind (mass loss) scheme for RGB stars
      integer function get_RGB_wind_scheme(AMUSE_value)
         use amuse_support, only: AMUSE_RGB_wind_scheme
         implicit none
         character(*), intent(out) :: AMUSE_value
         AMUSE_value = trim(AMUSE_RGB_wind_scheme)
         get_RGB_wind_scheme = 0
      end function get_RGB_wind_scheme

! Set the wind (mass loss) scheme for RGB stars
      integer function set_RGB_wind_scheme(AMUSE_value)
         use amuse_support, only: AMUSE_RGB_wind_scheme
         implicit none
         character(*), intent(in) :: AMUSE_value
         logical :: is_valid_wind_scheme
         if (is_valid_wind_scheme(AMUSE_value)) then
            AMUSE_RGB_wind_scheme = trim(AMUSE_value)
            set_RGB_wind_scheme = 0
         else
            set_RGB_wind_scheme = -1
         endif
      end function set_RGB_wind_scheme

! Return the wind (mass loss) scheme for AGB stars
      integer function get_AGB_wind_scheme(AMUSE_value)
         use amuse_support, only: AMUSE_AGB_wind_scheme
         implicit none
         character(*), intent(out) :: AMUSE_value
         AMUSE_value = trim(AMUSE_AGB_wind_scheme)
         get_AGB_wind_scheme = 0
      end function get_AGB_wind_scheme

! Set the wind (mass loss) scheme for AGB stars
      integer function set_AGB_wind_scheme(AMUSE_value)
         use amuse_support, only: AMUSE_AGB_wind_scheme
         implicit none
         character(*), intent(in) :: AMUSE_value
         logical :: is_valid_wind_scheme
         if (is_valid_wind_scheme(AMUSE_value)) then
            AMUSE_AGB_wind_scheme = trim(AMUSE_value)
            set_AGB_wind_scheme = 0
         else
            set_AGB_wind_scheme = -1
         endif
      end function set_AGB_wind_scheme

! Retrieve the current value of the Reimers wind (mass loss) efficiency
      integer function get_reimers_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_reimers_wind_efficiency
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_reimers_wind_efficiency
         get_reimers_wind_efficiency = 0
      end function get_reimers_wind_efficiency

! Set the current value of the Reimers wind (mass loss) efficiency
      integer function set_reimers_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_reimers_wind_efficiency
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_reimers_wind_efficiency = AMUSE_value
         set_reimers_wind_efficiency = 0
      end function set_reimers_wind_efficiency

! Retrieve the current value of the Blocker wind (mass loss) efficiency
      integer function get_blocker_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_blocker_wind_efficiency
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_blocker_wind_efficiency
         get_blocker_wind_efficiency = 0
      end function get_blocker_wind_efficiency

! Set the current value of the Blocker wind (mass loss) efficiency
      integer function set_blocker_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_blocker_wind_efficiency
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_blocker_wind_efficiency = AMUSE_value
         set_blocker_wind_efficiency = 0
      end function set_blocker_wind_efficiency

! Retrieve the current value of the de Jager wind (mass loss) efficiency
      integer function get_de_jager_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_de_jager_wind_efficiency
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_de_jager_wind_efficiency
         get_de_jager_wind_efficiency = 0
      end function get_de_jager_wind_efficiency

! Set the current value of the de Jager wind (mass loss) efficiency
      integer function set_de_jager_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_de_jager_wind_efficiency
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_de_jager_wind_efficiency = AMUSE_value
         set_de_jager_wind_efficiency = 0
      end function set_de_jager_wind_efficiency

! Retrieve the current value of the Dutch wind (mass loss) efficiency
      integer function get_dutch_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_dutch_wind_efficiency
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_dutch_wind_efficiency
         get_dutch_wind_efficiency = 0
      end function get_dutch_wind_efficiency

! Set the current value of the Dutch wind (mass loss) efficiency
      integer function set_dutch_wind_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_dutch_wind_efficiency
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_dutch_wind_efficiency = AMUSE_value
         set_dutch_wind_efficiency = 0
      end function set_dutch_wind_efficiency

      integer function get_van_Loon_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_van_Loon_wind_eta
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_van_Loon_wind_eta
         get_van_Loon_wind_eta = 0
      end function get_van_Loon_wind_eta

      integer function set_van_Loon_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_van_Loon_wind_eta
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_van_Loon_wind_eta = AMUSE_value
         set_van_Loon_wind_eta = 0
      end function set_van_Loon_wind_eta
      
      integer function get_Kudritzki_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_Kudritzki_wind_eta
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_Kudritzki_wind_eta
         get_Kudritzki_wind_eta = 0
      end function get_Kudritzki_wind_eta

      integer function set_Kudritzki_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_Kudritzki_wind_eta
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_Kudritzki_wind_eta = AMUSE_value
         set_Kudritzki_wind_eta = 0
      end function set_Kudritzki_wind_eta

      integer function get_Nieuwenhuijzen_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_Nieuwenhuijzen_wind_eta
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_Nieuwenhuijzen_wind_eta
         get_Nieuwenhuijzen_wind_eta = 0
      end function get_Nieuwenhuijzen_wind_eta

      integer function set_Nieuwenhuijzen_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_Nieuwenhuijzen_wind_eta
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_Nieuwenhuijzen_wind_eta = AMUSE_value
         set_Nieuwenhuijzen_wind_eta = 0
      end function set_Nieuwenhuijzen_wind_eta

      integer function get_Vink_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_Vink_wind_eta
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_Vink_wind_eta
         get_Vink_wind_eta = 0
      end function get_Vink_wind_eta

      integer function set_Vink_wind_eta(AMUSE_value)
         use amuse_support, only: AMUSE_Vink_wind_eta
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_Vink_wind_eta = AMUSE_value
         set_Vink_wind_eta = 0
      end function set_Vink_wind_eta


! Retrieve the current value of the convective overshoot parameter
      integer function get_convective_overshoot_parameter(AMUSE_value)
         use amuse_support, only: AMUSE_overshoot_f_all
         implicit none
         double precision, intent(out) :: AMUSE_value
         double precision :: check
         AMUSE_value = AMUSE_overshoot_f_all
         get_convective_overshoot_parameter = 0
      end function get_convective_overshoot_parameter

! Set the current value of the convective overshoot parameter
      integer function set_convective_overshoot_parameter(AMUSE_value)
         use amuse_support, only: AMUSE_overshoot_f_all
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_overshoot_f_all = AMUSE_value
!~         AMUSE_overshoot_f_above_nonburn = AMUSE_value
!~         AMUSE_overshoot_f_below_nonburn = AMUSE_value
!~         AMUSE_overshoot_f_above_burn_h = AMUSE_value
!~         AMUSE_overshoot_f_below_burn_h = AMUSE_value
!~         AMUSE_overshoot_f_above_burn_he = AMUSE_value
!~         AMUSE_overshoot_f_below_burn_he = AMUSE_value
!~         AMUSE_overshoot_f_above_burn_z = AMUSE_value
!~         AMUSE_overshoot_f_below_burn_z = AMUSE_value
         set_convective_overshoot_parameter = 0
      end function set_convective_overshoot_parameter

! Retrieve the current value of the mixing length ratio
      integer function get_mixing_length_ratio(AMUSE_value)
         use amuse_support, only: AMUSE_mixing_length_ratio
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_mixing_length_ratio
         get_mixing_length_ratio = 0
      end function get_mixing_length_ratio

! Set the current value of the mixing length ratio
      integer function set_mixing_length_ratio(AMUSE_value)
         use amuse_support, only: AMUSE_mixing_length_ratio
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_mixing_length_ratio = AMUSE_value
         set_mixing_length_ratio = 0
      end function set_mixing_length_ratio

! Retrieve the current value of the semi convection efficiency
      integer function get_semi_convection_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_semi_convection_efficiency
         implicit none
         double precision, intent(out) :: AMUSE_value
         AMUSE_value = AMUSE_semi_convection_efficiency
         get_semi_convection_efficiency = 0
      end function get_semi_convection_efficiency

! Set the current value of the semi convection efficiency
      integer function set_semi_convection_efficiency(AMUSE_value)
         use amuse_support, only: AMUSE_semi_convection_efficiency
         implicit none
         double precision, intent(in) :: AMUSE_value
         AMUSE_semi_convection_efficiency = AMUSE_value
         set_semi_convection_efficiency = 0
      end function set_semi_convection_efficiency

! Retrieve the current value of the do_stabilize_new_stellar_model flag
      integer function get_stabilize_new_stellar_model_flag(AMUSE_value)
         use amuse_support, only: do_stabilize_new_stellar_model
         implicit none
         integer, intent(out) :: AMUSE_value
         if (do_stabilize_new_stellar_model) then
            AMUSE_value = 1
         else
            AMUSE_value = 0
         end if
         get_stabilize_new_stellar_model_flag = 0
      end function get_stabilize_new_stellar_model_flag

! Set the current value of the do_stabilize_new_stellar_model flag
      integer function set_stabilize_new_stellar_model_flag(AMUSE_value)
         use amuse_support, only: do_stabilize_new_stellar_model
         implicit none
         integer, intent(in) :: AMUSE_value
         if (AMUSE_value /= 0) then
            do_stabilize_new_stellar_model = .true.
         else
            do_stabilize_new_stellar_model = .false.
         end if
         set_stabilize_new_stellar_model_flag = 0
      end function set_stabilize_new_stellar_model_flag

! Retrieve the maximum number of stars that can be allocated in the code
      integer function get_maximum_number_of_stars(AMUSE_value)
         use star_def, only: max_star_handles
         implicit none
         integer, intent(out) :: AMUSE_value
         AMUSE_value = max_star_handles
         get_maximum_number_of_stars = 0
      end function get_maximum_number_of_stars

! Create a new particle from a user supplied model (non-ZAMS, e.g. merger product)
!~   integer function new_specified_stellar_model(d_mass, radius, rho, temperature, luminosity, &
!~         XH, XHE, XC, XN, XO, XNE, XMG, XSI, XFE, n)
!~      use amuse_support
!~      use star_lib, only: alloc_star, star_setup, show_terminal_header
!~      use star_private_def, only: star_info, get_star_ptr
!~      use run_star_support, only: setup_for_run_star, before_evolve, failed
!~      use read_model, only: set_zero_age_params, finish_load_model
!~      use alloc, only: set_var_info, set_q_flag, allocate_star_info_arrays
!~      use micro, only: init_mesa_micro
!~      use init_model, only: get_zams_model
!~      use chem_lib, only: get_nuclide_index
!~      use star_utils, only: set_qs, set_q_vars
!~      use do_one_utils, only: set_phase_of_evolution
!~      use evolve_support, only: yrs_for_init_timestep
!~      use const_def, only: secyer, Msun, Lsun
!~
!~      implicit none
!~      integer, intent(in) :: n
!~      double precision, intent(in) :: d_mass(n), radius(n), rho(n), &
!~         temperature(n), luminosity(n), XH(n), XHE(n), XC(n), XN(n), &
!~         XO(n), XNE(n), XMG(n), XSI(n), XFE(n)
!~      double precision :: x(n)
!~      integer :: ierr, k
!~      type (star_info), pointer :: s
!~
!~      if (new_model_defined) then
!~         new_specified_stellar_model = -30
!~         return
!~      endif
!~
!~      new_specified_stellar_model = -1
!~      id_new_model = alloc_star(ierr)
!~      if (failed('alloc_star', ierr)) return
!~      call get_star_ptr(id_new_model, s, ierr)
!~      if (failed('get_star_ptr', ierr)) return
!~      call star_setup(id_new_model, AMUSE_inlist_path, ierr)
!~      if (failed('star_setup', ierr)) return
!~      ! Replace value of mass and metallicity just read, with supplied values.
!~      s% initial_mass = sum(d_mass)
!~      s% initial_z = AMUSE_initial_z
!~      s% zams_filename = trim(AMUSE_zamsfile)
!~      s% max_age = AMUSE_max_age_stop_condition
!~      s% min_timestep_limit = AMUSE_min_timestep_stop_condition
!~      s% max_model_number = AMUSE_max_iter_stop_condition
!~      s% mixing_length_alpha = AMUSE_mixing_length_ratio
!~      s% alpha_semiconvection = AMUSE_semi_convection_efficiency
!~      s% RGB_wind_scheme = AMUSE_RGB_wind_scheme
!~      s% AGB_wind_scheme = AMUSE_AGB_wind_scheme
!~      s% Reimers_wind_eta = AMUSE_reimers_wind_efficiency
!~      s% Blocker_wind_eta = AMUSE_blocker_wind_efficiency
!~      s% de_Jager_wind_eta = AMUSE_de_jager_wind_efficiency
!~      s% Dutch_wind_eta = AMUSE_dutch_wind_efficiency
!~      s% overshoot_f_above_nonburn = AMUSE_overshoot_f_above_nonburn
!~      s% overshoot_f_below_nonburn = AMUSE_overshoot_f_below_nonburn
!~      s% overshoot_f_above_burn_h = AMUSE_overshoot_f_above_burn_h
!~      s% overshoot_f_below_burn_h = AMUSE_overshoot_f_below_burn_h
!~      s% overshoot_f_above_burn_he = AMUSE_overshoot_f_above_burn_he
!~      s% overshoot_f_below_burn_he = AMUSE_overshoot_f_below_burn_he
!~      s% overshoot_f_above_burn_z = AMUSE_overshoot_f_above_burn_z
!~      s% overshoot_f_below_burn_z = AMUSE_overshoot_f_below_burn_z
!~
!~      s% doing_first_model_of_run = .true.
!~      s% dt = 0
!~      s% dt_old = 0
!~      call set_zero_age_params(s)
!~            s% net_name = 'basic.net'
!~      s% species = 0
!~      s% v_flag = .false.
!~      s% q_flag = .false.
!~      s% mstar = s% initial_mass*Msun
!~      call set_var_info(s, ierr)
!~      call init_mesa_micro(s, ierr) ! uses s% net_name
!~      s% generations = 1
!~
!~      if (n > s% max_allowed_nz) s% max_allowed_nz = n
!~      s% nz = n
!~      call allocate_star_info_arrays(s, ierr)
!~      if (failed('allocate_star_info_arrays', ierr)) return
!~      s% xh(s% i_xlnd, :) = log(rho(:))
!~      s% xh(s% i_lnT, :) = log(temperature(:))
!~      s% xh(s% i_lnR, :) = log(radius(:))
!~      if (luminosity(1) <= 0) then
!~         ! No luminosities provided, make an educated guess
!~         do k = 1, s% nz - 3
!~            if (temperature(k) .gt. 1.0e7) exit
!~         end do
!~         if (debugging) write(*,*) "temperature(", k, ") = ", temperature(k)
!~         if (debugging) write(*,*) "radius(", k, ") = ", radius(k)
!~         x = radius / radius(k)
!~         if (debugging) write(*,*) "x(", k, ") = ", x(k), x(1), x(s% nz)
!~         s% xh(s% i_lum, :) = Lsun * s% initial_mass**3.5 * (1.0 - (1.0 + x) * exp(-x**2 - x))
!~      else
!~         s% xh(s% i_lum, :) = luminosity(:)
!~      endif
!~      s% dq(:) = d_mass(:) / s% initial_mass
!~      s% xa(s% net_iso(get_nuclide_index('h1')), :) = XH(:)
!~      s% xa(s% net_iso(get_nuclide_index('he3')), :) = 0.0d0
!~      s% xa(s% net_iso(get_nuclide_index('he4')), :) = XHE(:)
!~      s% xa(s% net_iso(get_nuclide_index('c12')), :) = XC(:)
!~      s% xa(s% net_iso(get_nuclide_index('n14')), :) = XN(:)
!~      s% xa(s% net_iso(get_nuclide_index('o16')), :) = XO(:)
!~      s% xa(s% net_iso(get_nuclide_index('ne20')), :) = XNE(:)
!~      s% xa(s% net_iso(get_nuclide_index('mg24')), :) = XMG(:) + XSI(:) + XFE(:) ! basic net for now...
!~      s% prev_Lmax = maxval(abs(s% xh(s% i_lum, 1:n)))
!~      call set_qs(s% nz, s% q, s% dq, ierr)
!~      if (failed('set_qs', ierr)) return
!~      if (s% q_flag) call set_q_vars(s)
!~
!~      s% dt_next = yrs_for_init_timestep(s)*secyer
!~    !  s% dxs(:,:) = 0
!~      !
!~      s% extra_heat(:) = 0
!~      s% rate_factors(:) = 1
!~      call finish_load_model(s, ierr)
!~      call set_phase_of_evolution(s)
!~      if (s% q_flag) call set_q_flag(s% id, s% q_flag, ierr)
!~
!~      call setup_for_run_star(id_new_model, s, .false., ierr)
!~      if (failed('setup_for_run_star', ierr)) return
!~      call before_evolve(id_new_model, ierr)
!~      if (failed('before_evolve', ierr)) return
!~      if (debugging) s% trace_evolve = .true.
!~      if (debugging) s% report_ierr = .true.
!~      call show_terminal_header(id_new_model, ierr)
!~      if (failed('show_terminal_header', ierr)) return
!~      call flush()
!~      new_model_defined = .true.
!~      new_specified_stellar_model = 0
!~   end function new_specified_stellar_model
!~
!~   integer function new_stellar_model(d_mass, radius, rho, temperature, luminosity, &
!~         XH, XHE, XC, XN, XO, XNE, XMG, XSI, XFE, n)
!~      use amuse_support
!~      use star_lib, only: alloc_star, star_setup, show_terminal_header
!~      use star_def, only: result_reason_str
!~      use star_private_def, only: star_info, get_star_ptr
!~      use run_star_support, only: setup_for_run_star, before_evolve, failed
!~      use read_model, only: set_zero_age_params, finish_load_model
!~      use alloc, only: set_var_info, set_q_flag, allocate_star_info_arrays
!~      use micro, only: init_mesa_micro
!~      use init_model, only: get_zams_model
!~      use chem_lib, only: get_nuclide_index
!~      use star_utils, only: set_qs, set_q_vars
!~      use do_one_utils, only: set_phase_of_evolution
!~      use evolve_support, only: yrs_for_init_timestep
!~      use mesh_adjust, only: do_mesh_adjust
!~      use adjust_mesh, only: remesh
!~      use hydro_eqns, only: P_eqn_phot
!~      use hydro_vars, only: set_vars
!~      use const_def, only: secyer, Msun, Lsun
!~      use star_utils, only: set_xqs
!~
!~      implicit none
!~      integer, intent(in) :: n
!~      double precision, intent(in) :: d_mass(n), radius(n), rho(n), &
!~         temperature(n), luminosity(n), XH(n), XHE(n), XC(n), XN(n), &
!~         XO(n), XNE(n), XMG(n), XSI(n), XFE(n)
!~      double precision :: total_mass, original_timestep, f
!~      double precision :: original_timestep_limit, original_dxdt_nuc_f
!~      integer :: new_zams_star, ierr, tmp1_id_new_model, tmp2_id_new_model, &
!~         new_specified_stellar_model, finalize_stellar_model, match_mesh, &
!~         do_evolve_one_step, erase_memory, index_low, k1, k2
!~      logical :: do_T = .false.
!~      logical :: do_restore_timestep = .false.
!~      type (star_info), pointer :: s, s_tmp
!~
!~      if (new_model_defined) then
!~         new_stellar_model = -30
!~         return
!~      endif
!~
!~      ! *** Define a temporary star with the target 'new' structure: ***
!~      new_stellar_model = new_specified_stellar_model(d_mass, radius, rho, &
!~         temperature, luminosity, XH, XHE, XC, XN, XO, XNE, XMG, XSI, XFE, n)
!~      if (failed('new_specified_stellar_model', new_stellar_model)) return
!~
!~      if (do_stabilize_new_stellar_model) then
!~         new_stellar_model = -1
!~         if (debugging) write(*,*) 'tmp1_id_new_model', tmp1_id_new_model
!~         ierr = finalize_stellar_model(tmp1_id_new_model, 0.0d0)
!~         if (failed('finalize_stellar_model', ierr)) return
!~         call get_star_ptr(tmp1_id_new_model, s_tmp, ierr)
!~         if (failed('get_star_ptr', ierr)) return
!~         if (debugging) write(*,*) 'CHECK:', s_tmp% nz, n
!~
!~         ! *** Now, first create a normal ZAMS star ***
!~         total_mass = sum(d_mass)
!~         ierr = new_zams_star(tmp2_id_new_model, total_mass)
!~         if (failed('new_zams_star', ierr)) return
!~         id_new_model = tmp2_id_new_model
!~         if (debugging) write(*,*) 'id_new_model', id_new_model
!~         call get_star_ptr(id_new_model, s, ierr)
!~         if (failed('get_star_ptr', ierr)) return
!~
!~         ! *** Match the mesh containing the target structure to the mesh of the new particle ***
!~         ierr = match_mesh(tmp1_id_new_model, s% nz, s% dq)
!~         if (failed('match_mesh', ierr)) return
!~
!~         ! *** Copy the relevant variables (chemical fractions only, or also hydro vars...)
!~         original_timestep_limit = s% min_timestep_limit
!~         s% min_timestep_limit = 1.0d-12
!~         original_dxdt_nuc_f = s% dxdt_nuc_factor
!~         s% dxdt_nuc_factor = 1.0d-99
!~         original_timestep = s% dt_next
!~         f = 1.0d-4
!~         if (debugging) then
!~            s% trace_evolve = .true.
!~            s% report_ierr = .true.
!~         end if
!~         do
!~            s% xa(:,:) = f * s_tmp% xa(:,:) + (1.0d0 - f) * s% xa(:,:)
!~            ierr = erase_memory(id_new_model)
!~            if (failed('erase_memory', ierr)) return
!~            s% dt_next = 10.0 * s% min_timestep_limit
!~            ierr = do_evolve_one_step(id_new_model)
!~            if (failed('do_evolve_one_step', ierr)) return
!~            if (debugging) write(*,*) 'f: ', f
!~            call check_remeshed(s% nz, s_tmp% nz, s% dq, s_tmp% dq, ierr)
!~            if (failed('check_remeshed', ierr)) then
!~               ierr = match_mesh(tmp1_id_new_model, s% nz, s% dq)
!~               if (failed('match_mesh', ierr)) return
!~               call check_remeshed(s% nz, s_tmp% nz, s% dq, s_tmp% dq, ierr)
!~               if (failed('check_remeshed 2', ierr)) return
!~            end if
!~            if (debugging) write(*,*) 'CHECK check_remeshed OK'
!~            if (debugging) write(*,*) 'Backups', s% number_of_backups_in_a_row
!~            if (s% number_of_backups_in_a_row > 15) exit
!~            if (f >= 1.0d0) exit
!~            if (f >= 0.1d0) then
!~               f = min(1.1d0 * f, 1.0d0)
!~            else
!~               f = 1.5d0 * f
!~            endif
!~         end do
!~
!~         ! *** Give the model the opportunity to remesh ***
!~         s% mesh_delta_coeff = 0.5
!~         ierr = remesh(s, .true., .false., .false.)
!~         if (failed('remesh', ierr)) return
!~         ierr = erase_memory(id_new_model)
!~         if (failed('erase_memory', ierr)) return
!~         ierr = match_mesh(tmp1_id_new_model, s% nz, s% dq)
!~         if (failed('match_mesh', ierr)) return
!~         s% number_of_backups_in_a_row = 0
!~         s% mesh_delta_coeff = 1
!~
!~         ! *** Optionally, also do hydro vars ***
!~         if (do_T) then
!~            f = 1.0d-8
!~            index_low = s% nz / 10 ! Do not meddle with the atmosphere!
!~            do
!~               s% xa(:,:) = s_tmp% xa(:,:)
!~               s% xh(s% i_lnT,index_low:) = f*s_tmp%xh(s_tmp%i_lnT,index_low:) + (1d0-f)*s%xh(s%i_lnT,index_low:)
!~               ierr = erase_memory(id_new_model)
!~               if (failed('erase_memory', ierr)) return
!~               s% dt_next = 10.0 * s% min_timestep_limit
!~               ierr = do_evolve_one_step(id_new_model)
!~               if (failed('do_evolve_one_step', ierr)) return
!~               if (debugging) write(*,*) 'f: ', f
!~               call check_remeshed(s% nz, s_tmp% nz, s% dq, s_tmp% dq, ierr)
!~               if (failed('check_remeshed', ierr)) return
!~               if (debugging) write(*,*) 'CHECK check_remeshed OK'
!~               if (debugging) write(*,*) 'Backups', s% number_of_backups_in_a_row
!~               if (f >= 1.0d0) exit
!~               f = min(1.5d0 * f, 1.0d0)
!~            end do
!~         end if
!~
!~         ! *** Restore the original timestep ***
!~         if (debugging) write(*,*) 'timesteps', s% dt_old, s% dt, s% dt_next, original_timestep
!~         s% dt_next = 10.0 * s% min_timestep_limit
!~         s% dt = 10.0 * s% min_timestep_limit
!~         if (debugging) write(*,*) 'timesteps', s% dt_old, s% dt, s% dt_next, original_timestep
!~         ierr = do_evolve_one_step(id_new_model)
!~         if (debugging) write(*,*) ierr, s% result_reason, trim(result_reason_str(s% result_reason))
!~         if (debugging) write(*,*) 'timesteps', s% dt_old, s% dt, s% dt_next, original_timestep
!~         if (do_restore_timestep) then
!~            do k1 = 1, 10
!~               if (debugging) write(*,*) 'increasing timesteps', s% dt_old, s% dt, s% dt_next, original_timestep
!~               if (debugging) write(*,*) 'Backups', s% number_of_backups_in_a_row
!~               s% xa(:,:) = s_tmp% xa(:,:)
!~               if (do_T) s% xh(s% i_lnT,index_low:) = s_tmp% xh(s_tmp% i_lnT,index_low:)
!~               ierr = erase_memory(id_new_model)
!~               if (failed('erase_memory', ierr)) return
!~               do k2 = 1, 10
!~                  ierr = do_evolve_one_step(id_new_model)
!~                  if (debugging) write(*,*) ierr, s% result_reason, trim(result_reason_str(s% result_reason))
!~               end do
!~               if (s% number_of_backups_in_a_row > 0) exit
!~            end do
!~         end if
!~
!~         call check_remeshed(s% nz, s_tmp% nz, s% dq, s_tmp% dq, ierr)
!~         if (failed('check_remeshed', ierr)) then
!~            ierr = match_mesh(tmp1_id_new_model, s% nz, s% dq)
!~            if (failed('match_mesh', ierr)) return
!~            call check_remeshed(s% nz, s_tmp% nz, s% dq, s_tmp% dq, ierr)
!~            if (failed('check_remeshed 2', ierr)) return
!~         end if
!~         if (do_T) s% xh(s% i_lnT,index_low:) = s_tmp% xh(s_tmp% i_lnT,index_low:)
!~         ierr = erase_memory(id_new_model)
!~         if (failed('erase_memory', ierr)) return
!~
!~         s% dxdt_nuc_factor = original_dxdt_nuc_f
!~
!~         if (s% dt_next > 10.0 * original_timestep_limit) then
!~            s% min_timestep_limit = original_timestep_limit
!~         else
!~            s% min_timestep_limit = s% dt_next / 10.0
!~         endif
!~
!~         if (debugging) write(*,*) 'Backups:', s% number_of_backups_in_a_row
!~         s% number_of_backups_in_a_row = 0
!~         if (debugging) write(*,*) 'Backups reset:', s% number_of_backups_in_a_row
!~         s% trace_evolve = .false.
!~         s% report_ierr = .false.
!~         call flush()
!~         new_model_defined = .true.
!~         new_stellar_model = 0
!~      end if
!~
!~      contains
!~
!~      subroutine check_remeshed(nz, nz_orig, dq, dq_orig, ierr)
!~         implicit none
!~         integer, intent(in) :: nz, nz_orig
!~         double precision, intent(in) :: dq(nz), dq_orig(nz_orig)
!~         integer, intent(out) :: ierr
!~         integer :: i
!~         if (nz .ne. nz_orig) then
!~            ierr = -1
!~            return
!~         end if
!~         do i = 1, nz
!~            if (dq(i) .ne. dq_orig(i)) then
!~               ierr = -1
!~               return
!~            end if
!~         end do
!~         ierr = 0
!~      end subroutine check_remeshed
!~
!~   end function new_stellar_model
!~
!~   function finalize_stellar_model(star_id, age_tag)
!~      use amuse_support
!~      use run_star_support, only: failed
!~      use evolve, only: set_age
!~      implicit none
!~      integer :: finalize_stellar_model, ierr
!~      integer, intent(out) :: star_id
!~      double precision, intent(in) :: age_tag
!~
!~      if (.not. new_model_defined) then
!~         finalize_stellar_model = -35
!~         return
!~      endif
!~
!~      finalize_stellar_model = -1
!~      star_id = id_new_model
!~      number_of_particles = star_id
!~      call set_age(id_new_model, age_tag, ierr)
!~      if (failed('set_age', ierr)) return
!~      call flush()
!~
!~      new_model_defined = .false.
!~      finalize_stellar_model = 0
!~   end function
!~
!~   ! matches/interpolates existing mesh based on supplied dq's
!~   integer function match_mesh(model_id, nz_target, dq_target)
!~      use run_star_support, only: failed
!~      use amuse_support, only: debugging
!~      use star_private_def, only: star_info, get_star_ptr
!~      use alloc, only: free_star_info_arrays, allocate_star_info_arrays
!~      use mesh_plan, only: do_mesh_plan
!~      use mesh_adjust, only: do_mesh_adjust
!~      use adjust_mesh_support, only: check_validity
!~      use hydro_vars, only: set_vars
!~      use rates_def, only: i_rate, ipp, icno, i3alf, iphoto
!~      use net_lib, only: clean_up_fractions
!~      use num_lib, only: safe_log10
!~      use utils_lib
!~      use star_utils, only: set_q_vars, report_xa_bad_nums, &
!~         std_dump_model_info_for_ndiff, set_qs, set_xqs
!~      use chem_def
!~
!~      integer, intent(in) :: model_id, nz_target
!~      double precision, intent(inout) :: dq_target(nz_target)
!~
!~      type (star_info), pointer :: s_tmp
!~      logical, parameter :: dbg_remesh = .true.
!~      logical, parameter :: skip_net = .false., check_for_bad_nums = .true.
!~      integer :: k, k2, ierr, species, nvar, nz, nz_new, nz_old, &
!~         unchanged, split, merged
!~      type (star_info), target :: prev_info
!~      type (star_info), pointer :: prv
!~      double precision, pointer, dimension(:) :: xq_old, xq_new, energy
!~
!~      double precision, parameter :: max_sum_abs = 10d0
!~      double precision, parameter :: xsum_tol = 1d-2
!~      double precision, parameter :: h_cntr_limit = 0.5d0 ! for pre-MS decision
!~      double precision, parameter :: he_cntr_limit = 0.1d0 ! for RGB vs AGB decision
!~
!~ 3       format(a40,2i6,99(1pe26.16))
!~
!~      call get_star_ptr(model_id, s_tmp, ierr)
!~      if (failed('get_star_ptr', ierr)) return
!~      if (debugging) write(*,*) 'enter match_mesh'
!~      ierr = 0
!~      match_mesh = -1
!~
!~      species = s_tmp% species
!~      nz_old = s_tmp% nz
!~      nz = nz_old
!~      nz_new = nz_target
!~
!~      call clean_up_fractions(1, nz, species, nz, s_tmp% xa, max_sum_abs, xsum_tol, ierr)
!~      if (failed('clean_up_fractions', ierr)) return
!~
!~      nullify(xq_old, xq_new)
!~      allocate(energy(nz), stat=ierr)
!~
!~      energy(1:nz) = exp(s_tmp% lnE(1:nz))
!~
!~      s_tmp% mesh_call_number = s_tmp% mesh_call_number + 1
!~
!~      ! save pointers to arrays that will need to be updated for new mesh
!~      prv => prev_info
!~      prv = s_tmp ! this makes copies of pointers and scalars
!~
!~      if (associated(s_tmp% comes_from)) deallocate(s_tmp% comes_from)
!~      allocate(s_tmp% comes_from(nz_target), xq_old(nz), xq_new(nz_target), stat=ierr)
!~      if (failed('allocate', ierr)) return
!~
!~      call check_validity(s_tmp, ierr)
!~      if (failed('check_validity', ierr)) return
!~
!~      if (check_for_bad_nums) then
!~         if (has_bad_num(species*nz, s_tmp% xa)) then
!~            write(*,*) 'bad num in xa before calling mesh_plan: model_number', s_tmp% model_number
!~            call report_xa_bad_nums(s_tmp, ierr)
!~            stop 'remesh'
!~         end if
!~      end if
!~
!~      call set_xqs(nz, xq_old, s_tmp% dq, ierr)
!~      if (failed('set_xqs xq_old', ierr)) return
!~      call set_xqs(nz_target, xq_new, dq_target, ierr)
!~      if (failed('set_xqs xq_new', ierr)) return
!~
!~      ! Set comes_from
!~      !      ! xq_old(comes_from(k)+1) > xq_new(k) >= xq_old(comes_from(k)), if comes_from(k) < nz_old.
!~      s_tmp% comes_from(:) = 0
!~      k2 = 1
!~      s_tmp% comes_from(1) = k2
!~      do k = 2, nz_target
!~         do
!~            if (k2 == nz) exit
!~            if (xq_new(k) >= xq_old(k2+1)) then
!~               k2 = k2 + 1
!~            else
!~               exit
!~            end if
!~         end do
!~         s_tmp% comes_from(k) = k2
!~      end do
!~      nz = nz_new
!~      s_tmp% nz = nz
!~      nvar = s_tmp% nvar
!~
!~      call allocate_star_info_arrays(s_tmp, ierr)
!~      if (failed('allocate_star_info_arrays', ierr)) return
!~
!~      if (associated(s_tmp% cell_type)) deallocate(s_tmp% cell_type)
!~      allocate(s_tmp% cell_type(nz))
!~      call set_types_of_new_cells(s_tmp% cell_type)
!~
!~      s_tmp% rate_factors(1:prv% num_reactions) = prv% rate_factors(1:prv% num_reactions)
!~
!~      ! store new q and dq
!~      s_tmp% dq(:) = dq_target(:)
!~      call set_qs(nz, s_tmp% q, s_tmp% dq, ierr)
!~      if (failed('set_qs', ierr)) return
!~
!~      ! testing -- check for q strictly decreasing
!~      do k = 2, nz
!~         if (xq_new(k) <= xq_new(k-1)) then
!~            write(*,3) 'bad xq_new before call do_mesh_adjust', &
!~               k, nz, xq_new(k), xq_new(k-1), dq_target(k-1), xq_new(k-1) + dq_target(k-1)
!~            stop 'adjust mesh'
!~         end if
!~      end do
!~
!~      if (s_tmp% q_flag) call set_q_vars(s_tmp)
!~
!~      if (dbg_remesh) write(*,*) 'call do_mesh_adjust'
!~      call do_mesh_adjust( &
!~         nz, nz_old, prv% xh, prv% xa, energy, prv% eta, prv% dq, xq_old, &
!~         s_tmp% xh, s_tmp% xa, s_tmp% dq, xq_new, s_tmp% species, s_tmp% chem_id, s_tmp% net_iso, s_tmp% eos_handle, &
!~         s_tmp% mesh_adjust_use_quadratic, s_tmp% mesh_adjust_get_T_from_E, &
!~         s_tmp% i_xlnd, s_tmp% i_lnT, s_tmp% i_lnR, s_tmp% i_lum, s_tmp% i_vel, s_tmp% i_lndq, s_tmp% i_lnq, &
!~         s_tmp% q_flag, s_tmp% v_flag, &
!~         prv% mstar, s_tmp% comes_from, s_tmp% cell_type, ierr)
!~      if (failed('do_mesh_adjust', ierr)) return
!~      if (dbg_remesh) write(*,*) 'back from do_mesh_adjust'
!~
!~      ! testing
!~      do k = 2, nz
!~         if (xq_new(k) <= xq_new(k-1)) then
!~            write(*,3) 'bad xq_new after call do_mesh_adjust', k, nz, xq_new(k), xq_new(k-1)
!~            stop 'adjust mesh'
!~         end if
!~      end do
!~
!~      if (ierr /= 0 .and. s_tmp% report_ierr) then
!~         write(*,*) 'mesh_adjust problem'
!~         write(*,*) 'doing mesh_call_number', s_tmp% mesh_call_number
!~         write(*,*) 's_tmp% model_number', s_tmp% model_number
!~         write(*,*) 's_tmp% nz', s_tmp% nz
!~         write(*,*) 's_tmp% num_retries', s_tmp% num_retries
!~         write(*,*) 's_tmp% num_backups', s_tmp% num_backups
!~         write(*,*)
!~      end if
!~
!~      if (check_for_bad_nums) then
!~         if (has_bad_num(species*nz, s_tmp% xa)) then
!~            write(*,*) 'bad num in xa after calling mesh_adjust: model_number', s_tmp% model_number
!~            stop 'remesh'
!~         end if
!~      end if
!~
!~      if (s_tmp% prev_cdc_tau > 0) then ! interpolate cdc
!~         call set_prev_cdc(ierr)
!~         if (ierr /= 0 .and. s_tmp% report_ierr) &
!~            write(*,*) 'mesh_adjust problem: ierr from set_prev_cdc'
!~      end if
!~
!~      call free_star_info_arrays(prv)
!~
!~      call dealloc
!~      match_mesh = 0
!~
!~      contains
!~
!~      subroutine set_prev_cdc(ierr)
!~         use interp_1d_def
!~         use interp_1d_lib
!~         integer, intent(out) :: ierr
!~         integer, parameter :: nwork = pm_work_size
!~         double precision, pointer :: work(:,:)
!~         ierr = 0
!~         allocate(work(nz_old, nwork), stat=ierr)
!~         if (ierr /= 0) return
!~         call interpolate_vector( &
!~            nz_old, prv% q, nz, s_tmp% q, prv% cdc, s_tmp% cdc_prev, interp_pm, nwork, work, ierr)
!~         deallocate(work)
!~      end subroutine set_prev_cdc
!~
!~
!~      subroutine set_types_of_new_cells(cell_type)
!~         use mesh_adjust, only: split_type, unchanged_type, merged_type
!~         integer, pointer :: cell_type(:)
!~         integer :: k, k_old, new_type
!~
!~ 2       format(a40,2i6,99(1pe26.16))
!~
!~         unchanged=0; split=0; merged=0
!~
!~         do k=1,nz_new
!~            k_old = s_tmp% comes_from(k)
!~            new_type = -111
!~            if (xq_new(k) < xq_old(k_old)) then
!~               write(*,*) 'xq_new(k) < xq_old(k_old)'
!~               write(*,2) 'xq_new(k)', k, xq_new(k)
!~               write(*,2) 'xq_old(k_old)', k_old, xq_old(k_old)
!~               write(*,*) 'adjust mesh set_types_of_new_cells'
!~               stop 1
!~            else if (xq_new(k) > xq_old(k_old)) then
!~               new_type = split_type
!~            else if (k_old == nz_old) then
!~               if (k == nz_new) then
!~                  new_type = unchanged_type
!~               else
!~                  new_type = split_type
!~               end if
!~            else if (k == nz_new) then
!~               new_type = split_type
!~            else ! k_old < nz_old .and. k < nz .and. xq_new(k) == xq_old(k_old)
!~               if (xq_new(k+1) == xq_old(k_old+1)) then
!~                  new_type = unchanged_type
!~               else if (xq_new(k+1) > xq_old(k_old+1)) then
!~                  new_type = merged_type
!~               else
!~                  new_type = split_type
!~               end if
!~            end if
!~            cell_type(k) = new_type
!~            select case (new_type)
!~               case (split_type)
!~                  split = split + 1
!~               case (unchanged_type)
!~                  unchanged = unchanged + 1
!~               case (merged_type)
!~                  merged = merged + 1
!~               case default
!~                  write(*,*) 'failed to set new_type in adjust mesh set_types_of_new_cells'
!~                  stop 'set_types_of_new_cells'
!~            end select
!~         end do
!~
!~         if (unchanged + split + merged /= nz_new) then
!~            write(*,2) 'unchanged + split + merged', unchanged + split + merged
!~            write(*,2) 'nz_new', nz_new
!~            stop 'set_types_of_new_cells'
!~         end if
!~
!~      end subroutine set_types_of_new_cells
!~
!~      subroutine dealloc
!~         if (associated(xq_old)) deallocate(xq_old)
!~         if (associated(xq_new)) deallocate(xq_new)
!~         if (associated(energy)) deallocate(energy)
!~      end subroutine dealloc
!~
!~   end function match_mesh


