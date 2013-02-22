package nl.esciencecenter.estars;

import nl.esciencecenter.estars.glue.AmuseLib;
import nl.esciencecenter.estars.glue.Scene;

import amuse.code.CodeInterface;

public class Code implements CodeInterface {

    private final AmuseLib amuseLib;

    // private final ArrayList<Star> stars();

    public Code() {
        amuseLib = new AmuseLib();

    }

    @Override
    public int set_color(int[] index_of_the_particle, double[] red, double[] green, double[] blue, double[] alpha,
            int npoints) {
        System.err.println("set_color");
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    // first parameter is output parameter!
    public int new_particle(int[] index_of_the_particle, int[] type, double[] x, double[] y, double[] z,
            double[] radius, double[] red, double[] green, double[] blue, double[] alpha, int npoints) {

        System.err.println("new_particle");
        for (int i = 0; i < npoints; i++) {
            System.err.printf(
                    "new particle of type %d at position %.4f,%.4f,%.4f and radius %.4f with rgb %.4f,%.4f,%.4f\n",
                    type[i], x[i], y[i], z[i], radius[i], red[i], green[i], blue[i]);
        }

        return 0;
    }

    @Override
    public int set_type(int[] index_of_the_particle, int[] type, int npoints) {
        System.err.println("set_type");
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public int store_view(double time) {
        System.err.println("store view @ " + time);
        amuseLib.addScene(new Scene(time, null, null, null, null, null));
        return 0;
    }

    @Override
    public int cleanup_code() {
        System.err.println("cleanup_code!");
        return 0;
    }

    @Override
    public int recommit_parameters() {
        System.err.println("recommit_particles!");
        return 0;
    }

    @Override
    public int initialize_code() {
        System.err.println("initialize code!");
        return 0;
    }

    @Override
    public int set_position(int[] index_of_the_particle, double[] x, double[] y, double[] z, int npoints) {
        System.err.println("set_position");
        return 0;
    }

    @Override
    public int set_radius(int[] index_of_the_particle, double[] radius, int npoints) {
        System.err.println("set_radius");
        return 0;
    }

    @Override
    public int commit_parameters() {
        System.err.println("commit parameters!");
        return 0;
    }

    @Override
    public int commit_particles() {

        System.err.println("commit particles!");
        return 0;
    }

}
