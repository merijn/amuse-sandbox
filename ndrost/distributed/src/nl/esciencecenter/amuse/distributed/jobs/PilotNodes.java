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
package nl.esciencecenter.amuse.distributed.jobs;

import ibis.ipl.IbisIdentifier;
import ibis.ipl.RegistryEventHandler;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Set of nodes available to run jobs on
 * 
 * @author Niels Drost
 * 
 */
public class PilotNodes implements RegistryEventHandler {

    private static final Logger logger = LoggerFactory.getLogger(PilotNodes.class);

    private final ArrayList<PilotNode> nodes;

    private final JobManager jobManager;

    /**
     * @param jobManager
     */
    public PilotNodes(JobManager jobManager) {
        this.jobManager = jobManager;
        nodes = new ArrayList<PilotNode>();
    }

    /**
     * @return
     */
    public synchronized boolean isEmpty() {
        return nodes.isEmpty();
    }

    /**
     * @param job
     * @return
     */
    public synchronized PilotNode[] getSuitableNodes(Job job) {

        String label = job.getLabel();

        PilotNode[] result = new PilotNode[job.getNumberOfNodes()];
        int found = 0;

        for (int i = 0; i < nodes.size() && found < result.length; i++) {
            PilotNode node = nodes.get(i);

            if ((job.isWorkerJob() || node.isAvailableForBatchJobs()) && (label == null || label.equals(node.getLabel()))) {
                result[found] = node;
                found++;
            }
        }
        if (found != result.length) {
            logger.debug("no suitable nodes found for job {} in {}", job, nodes);
            return null;
        }

        if (logger.isDebugEnabled()) {
            logger.debug("looking for suitable node for job {} in {} resulted in {}", job, this, Arrays.toString(result));
        }

        return result;
    }

    @Override
    public synchronized void died(IbisIdentifier ibis) {
        //handle like it left
        left(ibis);
    }

    @Override
    public void joined(IbisIdentifier ibis) {
        logger.debug("new Ibis joined: " + ibis);

        synchronized (this) {
            //ignore local daemon node,
            if (!ibis.location().toString().equals("daemon@local")) {
                nodes.add(new PilotNode(ibis));
            }
        }

        jobManager.nudge();
    }

    @Override
    public void left(IbisIdentifier ibis) {
        logger.debug("Ibis left: " + ibis);

        Iterator<PilotNode> iterator = nodes.iterator();

        synchronized (this) {
            while (iterator.hasNext()) {
                if (iterator.next().getIbisIdentifier().equals(ibis)) {
                    iterator.remove();
                    //TODO: do something with the jobs still running on this node, if any...
                }
            }
        }
    }

    @Override
    public void electionResult(String name, IbisIdentifier winner) {
        //IGNORED
    }

    @Override
    public void gotSignal(String signal, IbisIdentifier origin) {
        //IGNORED
    }

    @Override
    public void poolClosed() {
        //IGNORED
    }

    @Override
    public void poolTerminated(IbisIdentifier arg0) {
        //IGNORED
    }

}