%%% "Distance-Ring Exponential Stations Generator (DRESG) for LPWANs"
%%% Author: Sergio Barrachina (sergio.barrachina@upf.edu)
%%% More info at S. Barrachina, B. Bellalta, T. Adame, and A. Bel, �Multi-hop Communication in the Uplink for LPWANs,� 
%%% arXiv preprint arXiv:1611.08703, 2016.
%%%
%%% File description: get optimal transmission configuration for a given
%%% ring hops combination. Suitable for single-hop, multi-hop and any other
%%% hops combinations.

function [e, btle_e, btle_ix, connectivity_matrix, ring_dest_array, results] = ...
        general_optimal_tx_conf(ring_hops_combination, aggregation_on, d_ring)

    % general_optimal_tx_conf returns ...
    %   - e = array representing the energy consumed by each ring
%   - ring_hops_combination: array representing the hop lenght of each ring

    load('configuration.mat')
    
    connectivity_matrix = get_connectivity_matrix(ring_hops_combination);   % Look paper for detailed info
    
    ring_dest_array = (1:num_rings) - ring_hops_combination(1,:);
    results = zeros(num_rings, RESULTS_NUM_ELEMENTS);
       
    for ring_aux_ix = 1:num_rings
        
        ring = num_rings - ring_aux_ix + 1;             % Start from the last ring
        ring_dest = ring_dest_array(ring);
        
        if ring_dest ~= 0
            d_to_parent = d_ring(ring) - d_ring(ring_dest);     % Distance to next-hop
        else
            d_to_parent = d_ring(ring);     % Distance to the GW
        end
        
        D_max = zeros(length(P_LVL),length(R_LVL));     % Maximum distance matrix
        e_opt = 100000000000;                           % Optimal consumption (to be minimized)
        
        for pow_ix = 1:length(P_LVL)
                        
            for rate_ix = 1:length(R_LVL)
                                
                % Compute maximum communication range. Notice that the sensibility
                % depends on the transmission rate (i.e., modulation).
                D_max(pow_ix,rate_ix) = max_distance(prop_model, P_LVL(pow_ix), Grx, Gtx, S(rate_ix), f);
        
                if D_max(pow_ix,rate_ix) >= d_to_parent
                                         
                    rate = R_LVL(rate_ix);
                    % Transmission
                    ring_payloads_ix = find(connectivity_matrix(ring,:)==1);
                    num_payloads = sum(n(ring_payloads_ix)) / n(ring);    % Max number of payload to be txd (subtree size)
                    
                    max_num_payloads = num_payloads;
                    % num_dfs_tx = ceil(num_payloads / p_ratio);  % Padding taken into account
                    
                    % Get number of L_DP packets to transmit
                    if aggregation_on
                        num_packets = get_num_packets(num_payloads, p_ratio);                       
                    else
                        num_packets = num_payloads;
                    end
                    
                    ring_load = num_payloads;
                    t_tx = (num_packets * L_DP * 8) / rate;
                    e_tx = t_tx * (I_LVL(pow_ix) * V);
                    
                    % Reception
                    t_rx = 0;
                    num_packets_rx = 0;
                    
                    for source_ring_ix=1:num_rings
                        
                        if ring_dest_array(source_ring_ix) == ring     % If source ring is linked to current ring
                            
                            link_children_ratio = n(source_ring_ix)/n(ring);
                            num_dfs_per_child =  results(source_ring_ix, RESULTS_IX_DFS_RING_LOAD);
                            num_packets_rx = num_packets_rx + link_children_ratio * num_dfs_per_child;
                            t_rx = t_rx + (link_children_ratio * num_dfs_per_child * L_DP * 8) / ... 
                                R_LVL(results(source_ring_ix, RESULTS_IX_R_LVL));
                            
                        end
                    end
                    
                    e_rx = t_rx * I_rx * V;
                    
                    if (e_tx + e_rx) < e_opt % Optimize the transmission energy
                        
                        P_opt = P_LVL(pow_ix);
                        ix_P = pow_ix;
                        r_opt = R_LVL(rate_ix);
                        ix_r = rate_ix;
                        e_opt = e_tx + e_rx;
                        
                        results(ring, RESULTS_IX_ENERGY_TX) = e_tx;
                        results(ring, RESULTS_IX_POWER_OPT) = P_opt;
                        results(ring, RESULTS_IX_POWER_LVL) = ix_P;
                        results(ring, RESULTS_IX_R_OPT) = r_opt;
                        results(ring, RESULTS_IX_R_LVL) = ix_r;
                        results(ring, RESULTS_IX_ENERGY_RX) = e_rx;
                        results(ring, RESULTS_IX_RING_LOAD) = ring_load;
                        results(ring, RESULTS_IX_MAX_RING_LOAD) = max_num_payloads;
                        results(ring, RESULTS_IX_DFS_RING_LOAD) = num_packets;
                        results(ring, RESULTS_IX_RING_DESTIINATION) = ring_dest;
                        results(ring, RESULTS_IX_NUM_PACKETS_RX) = num_packets_rx;

                    end
                end
            end
        end
    end
    
    e = results(:,RESULTS_IX_ENERGY_TX) + results(:,RESULTS_IX_ENERGY_RX);
    [btle_e, btle_ix] = max(e);
    
end