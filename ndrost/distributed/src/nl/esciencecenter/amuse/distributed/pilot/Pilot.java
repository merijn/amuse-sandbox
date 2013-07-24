/*
 * Copyright 2013 Netherlands eScience Center
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package nl.esciencecenter.amuse.distributed.pilot;

import ibis.ipl.Ibis;
import ibis.ipl.IbisCreationFailedException;
import ibis.ipl.IbisFactory;
import ibis.ipl.IbisIdentifier;
import ibis.ipl.IbisProperties;
import ibis.ipl.MessageUpcall;
import ibis.ipl.ReadMessage;
import ibis.ipl.ReceivePort;
import ibis.ipl.ReceivePortConnectUpcall;
import ibis.ipl.ReceivePortIdentifier;
import ibis.ipl.SendPort;
import ibis.ipl.SendPortIdentifier;
import ibis.ipl.WriteMessage;

import java.io.File;
import java.io.IOException;
import java.net.InetAddress;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Properties;

import nl.esciencecenter.amuse.distributed.AmuseConfiguration;
import nl.esciencecenter.amuse.distributed.DistributedAmuse;
import nl.esciencecenter.amuse.distributed.WorkerDescription;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Pilot job. Started when a reservations is made.
 * 
 * @author Niels Drost
 * 
 */
public class Pilot implements MessageUpcall, ReceivePortConnectUpcall {
    
    public static final String PORT_NAME = "pilot";

    private static final Logger logger = LoggerFactory.getLogger(Pilot.class);

    private final Ibis ibis;

    private final ReceivePort receivePort;

    private final HashMap<Integer, JobRunner> jobs;

    private final AmuseConfiguration configuration;

    Pilot(AmuseConfiguration configuration, Properties properties, String nodeLabel, int slots)
            throws IbisCreationFailedException, IOException {
        this.configuration = configuration;
        jobs = new HashMap<Integer, JobRunner>();

        //label, slots, hostname
        String tag = nodeLabel + "," + slots + "," + InetAddress.getLocalHost().getHostAddress();

        ibis =
                IbisFactory.createIbis(DistributedAmuse.IPL_CAPABILITIES, properties, true, null, null, tag, DistributedAmuse.ONE_TO_ONE_PORT_TYPE,
                        DistributedAmuse.MANY_TO_ONE_PORT_TYPE);

        receivePort = ibis.createReceivePort(DistributedAmuse.MANY_TO_ONE_PORT_TYPE, PORT_NAME, this, this, null);
    }

    /**
     * Small run function. Waits until the "main" distributed amuse node declares it is time to go.
     * 
     * @throws IOException
     */
    private void run() throws IOException {
        receivePort.enableConnections();
        receivePort.enableMessageUpcalls();

        //Wait until the pool is terminated by the DistributedAmuse master node
        //FIXME: no way to interrupt this wait.
        ibis.registry().waitUntilTerminated();

        logger.debug("Pool terminated");

        ibis.end();
    }

    public static void main(String[] arguments) throws Exception {
        File amuseHome = null;
        String nodeLabel = "default";
        int slots = 1;

        Properties properties = new Properties();
        properties.put(IbisProperties.POOL_NAME, "amuse");
        properties.put(IbisProperties.SERVER_IS_HUB, "false");
        //properties.put("ibis.managementclient", "true");
        //properties.put("ibis.bytescount", "true");

        for (int i = 0; i < arguments.length; i++) {
            if (arguments[i].equalsIgnoreCase("--node-label")) {
                i++;
                nodeLabel = arguments[i];
            } else if (arguments[i].equalsIgnoreCase("--resource-name")) {
                i++;
                properties.put(IbisProperties.LOCATION, arguments[i]);
            } else if (arguments[i].equalsIgnoreCase("--server-address")) {
                i++;
                properties.put(IbisProperties.SERVER_ADDRESS, arguments[i]);
            } else if (arguments[i].equalsIgnoreCase("--amuse-home")) {
                i++;
                amuseHome = new File(arguments[i]);
            } else if (arguments[i].equalsIgnoreCase("--hub-addresses")) {
                i++;
                properties.put(IbisProperties.HUB_ADDRESSES, arguments[i]);
            } else if (arguments[i].equalsIgnoreCase("--slots")) {
                i++;
                slots = Integer.parseInt(arguments[i]);
            } else {
                System.err.println("Unknown command line option: " + arguments[i]);
                System.exit(1);
            }
        }

        AmuseConfiguration configuration = new AmuseConfiguration(amuseHome);

        System.err.println("running Pilot using properties:");
        for (Entry<Object, Object> entry : properties.entrySet()) {
            System.err.println(entry.getKey() + " = " + entry.getValue());
        }

        Pilot pilot = new Pilot(configuration, properties, nodeLabel, slots);

        pilot.run();
        
        logger.debug("Main pilot thread ended");
    }

    private synchronized void addJobRunner(int jobID, JobRunner jobRunner) {
        jobs.put(jobID, jobRunner);
    }

    private synchronized JobRunner getJobRunner(int jobID) {
        return jobs.get(jobID);
    }

    private synchronized void removeFinishedJobs() {
        Iterator<Map.Entry<Integer, JobRunner>> iterator = jobs.entrySet().iterator();
        //remove all finished jobs
        while (iterator.hasNext()) {
            Map.Entry<Integer, JobRunner> entry = iterator.next();
            if (!entry.getValue().isAlive()) {
                iterator.remove();
            }
        }

    }

    /**
     * Handle incoming message from the amuse node
     */
    @Override
    public void upcall(ReadMessage readMessage) throws IOException, ClassNotFoundException {
        logger.debug("Received message upcall");

        String replyMessage = "ok";

        //run cleanup
        removeFinishedJobs();

        ReceivePortIdentifier replyPort = (ReceivePortIdentifier) readMessage.readObject();

        String command = readMessage.readString();

        if (command.equals("start")) {
            //details of job
            int jobID = readMessage.readInt();
            WorkerDescription description = (WorkerDescription) readMessage.readObject();
            IbisIdentifier[] nodes = (IbisIdentifier[]) readMessage.readObject();
            readMessage.finish();

            //FIXME: transfer files etc

            try {
                JobRunner jobRunner = new JobRunner(jobID, description, configuration, nodes, ibis);

                addJobRunner(jobID, jobRunner);

                //start a thread to run job.
                jobRunner.start();
            } catch (Exception e) {
                logger.error("Error starting job", e);
                replyMessage = "Error starting job: " + e;
            }
        } else if (command.equals("cancel")) {
            int jobID = readMessage.readInt();
            readMessage.finish();

            JobRunner jobRunner = getJobRunner(jobID);

            if (jobRunner != null) {
                //signal the thread it is time to cancel the job
                jobRunner.interrupt();
            }
        } else {
            logger.error("Failed to handle message, unknown command: " + command);
            replyMessage = "unknown command: " + command;
        }

        //send reply
        SendPort sendPort = ibis.createSendPort(DistributedAmuse.ONE_TO_ONE_PORT_TYPE);

        sendPort.connect(replyPort);

        WriteMessage reply = sendPort.newMessage();

        reply.writeString(replyMessage);

        reply.finish();

        sendPort.close();

    }

    /**
     * @param receiver
     * @param applicant
     * @return
     */
    @Override
    public boolean gotConnection(ReceivePort receiver, SendPortIdentifier applicant) {
        logger.debug("Got connection from {}", applicant);
        return true;
    }

    /**
     * @param receiver
     * @param origin
     * @param cause
     */
    @Override
    public void lostConnection(ReceivePort receiver, SendPortIdentifier origin, Throwable cause) {
        logger.debug("Lost connection to {}", origin);

    }

}
