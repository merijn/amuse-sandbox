int fev_triad(realtype t, N_Vector yev, N_Vector ydot, void *data);
int fev_delaunay(realtype t, N_Vector yev, N_Vector ydot, void *data);
double f_tides1(double e_p2);
double f_tides2(double e_p2);
double f_tides3(double e_p2);
double f_tides4(double e_p2);
double f_tides5(double e_p2);
double f_25PN_e(double e_p2);
double f_25PN_a(double e_p2);
double f_a_dot_mass_variations(double m_donor, double m_donor_dot, double m_accretor, double a, double beta, double gamma);
double f_a_dot_mass_variations_fast_and_isotropic_wind(double m_donor, double m_donor_dot, double m_accretor, double a, double beta);
int froot_delaunay(realtype t, N_Vector yev, realtype *gout, void *data);
double dimensionless_roche_radius_sepinsky_fit(double q, double f, double e);
