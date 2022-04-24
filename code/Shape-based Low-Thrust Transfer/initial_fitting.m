%% Project: 
% Date: 01/02/22

%% Initial fitting %%
% Function to estimate the trajectory approximation

% Inputs: - scalar n, the degree of the approximation 
%         - vector tau, the control parameter vector 
%         - C, the initial trajectory estimation
%         - string basis, the Bernstein polynomial basis to be used

% Outputs: - array P, the estimation of the boundary control points as a
%            cell
%          - array C, the initial estimation of the spacecraft state vector

function [P, C] = initial_fitting(n, tau, C, basis)
    % Preallocation of the control points and the polynomials
    P = zeros(length(n),max(n)+1); 
    B = cell(length(n),1);

    switch (basis)
        case 'Bernstein'
            for i = 1:length(n)
                B{i} = [bernstein_basis(n(i),tau) bernstein_derivative(n(i),tau,1) bernstein_derivative(n(i),tau,2)];
            end
        case 'Orthogonal Bernstein'
            for i = 1:length(n)
                B{i} = [OB_basis(n(i),tau) OB_derivative(n(i),tau,1) OB_derivative(n(i),tau,2)];
            end
        otherwise
            error('No valid collocation polynomial basis has been selected');
    end

    % Compute the position control points leveraging the complete state vector
    C = [C(1:size(P,1),:) C(size(P,1)+1:2*size(P,1),:) C(2*size(P,1)+1:3*size(P,1),:)];
    for i = 1:length(n)
        P(i,1:n(i)+1) = C(i,:)*pinv(B{i});
    end

    % Computation of the Bernstein basis
    B = state_basis(n,tau,basis);
    
    % Evaluate the state vector
    C = evaluate_state(P, B, n);
end