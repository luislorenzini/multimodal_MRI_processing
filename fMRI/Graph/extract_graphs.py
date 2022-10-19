#!/usr/bin/env python3

"""
Script to extract graph properties (as .csv file)
Connectome input has to be in .csv format

Created by Martijn Piet
Last updated on 30-5-2022
"""

# Import libraries
import numpy as np
import pandas as pd
import scipy
from scipy.linalg import block_diag
import bct
import os
import matplotlib.pyplot as plt
import glob
from nilearn import plotting 

# Define data
bidsdir="/home/llorenzini/lood_storage/divi/Projects/ExploreASL/insight46"
cohort = os.path.basename(bidsdir)
atlas_info = pd.read_csv(os.path.join(bidsdir,"scripts", "multimodal_MRI_processing", "atlases", "Schaefer2018_100Parcels_7Networks_order.txt"), sep = '\t', header=None).to_numpy() # Scheafer 100 is used
area_names = atlas_info[:,1]
datadir = os.path.join(bidsdir, "derivatives", "fmriprep")
resultdir = os.path.join(datadir, "Graph_Properties")


if not os.path.exists(resultdir):
    os.makedirs(resultdir)

    
modalities = ["fc"] #["fc","dti"]
metrics = ["ID","density","nVertices","nEdges","avgStrength",
           "avgBetweenness","avgClustering","charPath","small_world_coef","Gamma","Lambda" ]
#, 
#          "Vis_strength", "SomMot_strength", "DorsAttn_strength", "SalVenAttn_strength", "Limbic_strength", 
#           "Cont_strength", "Default_strength"]


# For participation coefficient  and network strengths
netlabels = pd.read_csv(os.path.join(bidsdir,"scripts", "multimodal_MRI_processing", "atlases", "Schaeffer_Networks_labels.txt"), sep = '\t', header=None)
netnum = [1,2,3,4,5,6,7]
netname = ["Vis", "SomMot", "DorsAttn", "SalVentAttn", "Limbic", "Cont", "Default"]
netlabels_rc = netlabels.replace(netname, netnum)


### Other settings
richclubnames=["K_raw_15", "K_raw_16", "K_raw_17", "K_raw_18", "K_raw_19", "K_raw_20","K_raw_21", "K_raw_22", "K_raw_23", "K_raw_24","K_raw_25", "K_norm_15", "K_norm_16", "K_norm_17", "K_norm_18", "K_norm_19",                "K_norm_20","K_norm_21", "K_norm_22",   "K_norm_23", "K_norm_24","K_norm_25"]


# Dictionaries are used to define and save data
global_prop = {}
reg_prop = {}
allnetsdf = {}  # to store strenght of within network connections

global_prop["fc"] = []
reg_prop["fc_RSN_strengths"] = []
reg_prop["fc_strength"] = []
reg_prop["fc_btwness"] = []
reg_prop["fc_clust"] = []
reg_prop["fc_participation"] = []
reg_prop["fc_richclub"]= []  # rich club is not regional but per k-level, but we store it in the regional dataset as its many values
    
for subname in os.listdir(datadir):   # Iterate across subjects 
    if subname.endswith("html"):
        continue
    if not subname.startswith("sub"):
        continue

    print(subname)
    for sesfold in glob.glob(os.path.join(datadir, subname, '*ses*')):  # Iterate across session
        
        ses = os.path.basename(sesfold)  ## Name of Session
        
        if os.path.exists(os.path.join(resultdir, subname, ses)):
            print("Graph properties already computed for subject " + subname + " for session " + ses  + " delete output folder to rerun  \n \nGoing to the next subject/session")
            continue
        else :
            os.makedirs(os.path.join(resultdir, subname, ses))
            
            
        
        
        
        ## Specify connectome locations
        #connectomes = {}
        
        
        cc = glob.glob(os.path.join(datadir, subname, ses, "func", subname + "_" + ses + "_task-rest_space-T1w_schaeffer_100_connectome.csv"))
        # if "dti" in modalities:
        #     if cohort == "EPAD":
        #         connectomes["dti"] = os.path.join(datadir, subname, "dwi", subname + "_connectome.csv")
        #     elif cohort == "Twins":
        #         connectomes["dti"] = os.path.join(datadir, subname, "schaeffer_100_sift2.csv")
    
        # if "fc" in modalities:
        # # Depending on the cohort the name of the file differs
        #     if cohort == "EPAD":
        #         connectomes["fc"] = os.path.join(datadir, subname, "FC_cc_schaefer100.csv")
        #     elif cohort == "Twins":
        #         connectomes["fc"] = os.path.join(datadir, subname, subname + "_ses-01_task-rest_space-T1w_schaeffer_100_connectome.csv")
    
        # Main loop that computes graph properties per modality
        
        if cc:
            print(f"Now processing {cc}")
            connMat = np.genfromtxt(cc[0], delimiter=',')
#plotting.plot_matrix(connMat, vmax = 1, vmin = -1, colorbar = True)
            connMat[np.isnan(connMat)] = 0
            connMat[connMat<0] = 0

            # Remove all self-self connections
            connMat[np.diag_indices_from(connMat)] = 0

            # Matrix Thresholding
            thr_connMat = bct.threshold_proportional(connMat, 0.3)
            thr_connMat[thr_connMat>0] = 1

            # SVD Normalization
#            u,s,v = scipy.linalg.svd(connMat)
#            sScaled = (10/s[0])*s
#            s_mt = np.diag(sScaled)
#            norm_connMat = u @  s_mt @ v

            ### Graph properties
            [density,nVertices,nEdges] = bct.density_und(thr_connMat)

            # Regional measures
            reg_strength = bct.strengths_und_sign(connMat) ## Compute on unthresholded matrix
            reg_betweenness = bct.betweenness_bin(thr_connMat)
            reg_clust = bct.clustering_coef_bu(thr_connMat)

            # Global measures
            avgStrength = np.mean(reg_strength[0])
            avgBtwness = np.mean(reg_betweenness)
            avgClus = np.mean(reg_clust)
            cPathGraph = bct.charpath(thr_connMat)[0]

            ## Small worldness
            nRand = 50    # Amount of random graphs
            rewirePar = 8 # Average rewire per edge in randmio
            Alpha = 1 # Fraction of edges to rewire
            clusRand = np.zeros(nRand)
            cPathRand =  np.zeros(nRand)

            #Rich Club coefficient
            RC = bct.rich_club_bu(thr_connMat)  # check for what to extract from rich club
            RCraw = RC[0][14:25]
            
            # Create a random graph with similair properties
            for i in range(nRand):
                # [randMat,eff] = bct.randmio_und(thr_connMat,rewirePar)
                randMat = bct.randomizer_bin_und(thr_connMat,Alpha).astype(float)
                clusRand[i] = np.mean(bct.clustering_coef_bu(randMat))
                cPathRand[i] = bct.charpath(randMat)[0]
                RCrand = bct.rich_club_bu(randMat)  # check for what to extract from rich club
                RCrawrand = RCrand[0][14:25]


            # Calculate small worldness
            Gamma = avgClus/np.mean(clusRand) # Gamma
            Lambda = cPathGraph/np.mean(cPathRand) # Lambda
            SWcoef = Gamma/Lambda # small-word coefficient
            
            # Calculate normalized richclub 
            RCnorm = RCraw/RCrawrand
            
            # participation coefficient
            reg_pt = bct.participation_coef(thr_connMat, netlabels_rc)
            
            
            # mean strenght within RSN (non binarized)
            nplab = netlabels.to_numpy
            allnets = []#{}
            for net in netname:
#                print(netarea_names) 
                #allnets[net] = []
                netind=netlabels.loc[netlabels[0] == net].index
                netconn = np.triu(connMat[np.ix_(netind, netind)]) # Extract a submatrix
                netstrength = np.mean(netconn)
                allnets = np.append(allnets, netstrength)
                #allnets[net] = netstrength
                
            
            ## Save properties for each subject
           
            # Global
            glob_DF = pd.DataFrame([subname,density,nVertices,nEdges,avgStrength,avgBtwness,avgClus,cPathGraph,SWcoef,Gamma,Lambda])
            glob_DF = pd.DataFrame.transpose(glob_DF)
            glob_DF.columns = metrics
            glob_DF.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_global_graph_properties.csv"))) # Save as .csv
            
            # RSN strength
            rsnstrength = (pd.DataFrame(np.append(subname,allnets)))
            rsnstrength = pd.DataFrame.transpose(rsnstrength)
            rsnstrength.columns = np.append("ID", netname)
            rsnstrength.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_RSN_Strengths.csv"))) # Save as .csv

            # Local strength
            localstrength = pd.DataFrame(np.append(subname,reg_strength[0]))
            localstrength = pd.DataFrame.transpose(localstrength)
            localstrength.columns = np.append("ID", area_names)
            localstrength.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_local_Strengths.csv"))) # Save as .csv

            # Local betweenness
            localbtw = pd.DataFrame(np.append(subname,reg_betweenness))
            localbtw = pd.DataFrame.transpose(localbtw)
            localbtw.columns = np.append("ID", area_names)
            localbtw.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_local_Betwennes.csv"))) # Save as .csv

            # Local clust
            localclust = pd.DataFrame(np.append(subname,reg_clust))
            localclust = pd.DataFrame.transpose(localclust)
            localclust.columns = np.append("ID", area_names)
            localclust.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_local_clust.csv"))) # Save as .csv

            # Local participation
            localpart = pd.DataFrame(np.append(subname, reg_pt))
            localpart = pd.DataFrame.transpose(localpart)
            localpart.columns = np.append("ID", area_names)
            localpart.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_local_participation.csv"))) # Save as .csv
             
             # Rich club
            richclub = pd.DataFrame(np.append(np.append(subname, RCraw), RCnorm))
            richclub = pd.DataFrame.transpose(richclub)
            richclub.columns = np.append("ID", richclubnames)
            richclub.to_csv(os.path.join(os.path.join(resultdir, subname, ses, subname + "_rich_club.csv"))) # Save as .csv

            
### Second step: Concatenate all the results

print(" Saving Group Datasets")
# Create empty dataframes

glob_DF=pd.DataFrame(columns=metrics)
rsnstrength = pd.DataFrame(columns = np.append("ID", netname))
localstrength = pd.DataFrame(columns = np.append("ID", area_names))
localbtw = pd.DataFrame(columns = np.append("ID", area_names))
localclust = pd.DataFrame(columns = np.append("ID", area_names))
localpart = pd.DataFrame(columns = np.append("ID", area_names))
richclub = pd.DataFrame(columns = np.append("ID", richclubnames))


# Iterate and append
for subname in os.listdir(resultdir): 
    if not subname.startswith("sub"):
        continue
     
    # Iterate across session
    for sesfold in glob.glob(os.path.join(resultdir, subname, '*ses*')): 
        
        ses = os.path.basename(sesfold)  ## Name of Session
        if os.path.exists(os.path.join(resultdir,subname, ses, subname + "_global_graph_properties.csv")):
            # Global metrics  
            globsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_global_graph_properties.csv"))
            glob_DF = glob_DF.append(globsubdf)
            
            # RSN strenght
            rsnstrsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_RSN_Strengths.csv"))
            rsnstrength = rsnstrength.append(rsnstrsubdf)   
            
            # Local strength
            lclstrsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_local_Strengths.csv"))
            localstrength = localstrength.append(lclstrsubdf)   
    
            # Local Betweenness
            btwsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_local_Betwennes.csv"))
            localbtw = localbtw.append(btwsubdf)   
    
            # Local Clustering 
            clstsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_local_clust.csv"))
            localclust = localclust.append(clstsubdf)   
    
            # local Participation Coefficient
            rcsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_local_participation.csv"))
            localpart = localpart.append(rcsubdf)   
           
            # Rich club
            rcsubdf = pd.read_csv(os.path.join(resultdir,subname, ses, subname + "_rich_club.csv"))
            richclub = richclub.append(rcsubdf)   

        
# Export results

    glob_DF.to_csv(os.path.join(resultdir, "global_graph_properties.csv")) # Save as .csv
    rsnstrength.to_csv(os.path.join(resultdir, "RSN_strengths.csv"))
    localstrength.to_csv(os.path.join(resultdir, "local_strength.csv"))
    localbtw.to_csv(os.path.join(resultdir, "local_betweenness.csv"))
    localclust.to_csv(os.path.join(resultdir, "local_clustering.csv"))
    localpart.to_csv(os.path.join(resultdir, "local_participation.csv"))
    richclub.to_csv(os.path.join(resultdir, "RichClub.csv"))

# for mod in modalities:
#     glob_DF = pd.DataFrame(global_prop[mod])
#     glob_DF.columns = metrics
#     glob_DF.to_csv(os.path.join(resultdir, mod + "_graph_properties.csv")) # Save as .csv

#     # Regional
#     RSN_strengths_DF = pd.DataFrame(reg_prop[mod + "_RSN_strengths"], columns = np.append("ID", netname))
#     RSN_strengths_DF.to_csv(os.path.join(resultdir, mod + "_RSN_strengths.csv"))
#     strength_DF = pd.DataFrame(reg_prop[mod + "_strength"], columns = np.append("ID", area_names))
#     strength_DF.to_csv(os.path.join(resultdir, mod + "_reg_strength.csv"))
#     btwness_DF = pd.DataFrame(reg_prop[mod + "_btwness"], columns = np.append("ID", area_names))
#     btwness_DF.to_csv(os.path.join(resultdir, mod + "_reg_betweenness.csv"))
#     clust_DF = pd.DataFrame(reg_prop[mod + "_clust"], columns = np.append("ID", area_names))
#     clust_DF.to_csv(os.path.join(resultdir, mod + "_reg_clustering.csv"))
#     part_DF = pd.DataFrame(reg_prop[mod + "_participation"], columns = np.append("ID", area_names))
#     part_DF.to_csv(os.path.join(resultdir, mod + "_reg_participation.csv"))
#     RC_DF = pd.DataFrame(reg_prop[mod + "_richclub"], columns = np.append("ID", richclubnames))
#     RC_DF.to_csv(os.path.join(resultdir, mod + "_RichClub.csv"))

# print(f"Process finished: graph properties saved to {datadir}")

