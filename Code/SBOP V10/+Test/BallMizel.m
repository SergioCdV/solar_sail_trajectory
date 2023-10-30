%% Project: SBOPT %%
% Date: 12/05/23

%% Kang %% 
% This script provides a main interface to solve Kang's problem %

%% Set up
close all
clear

%% Numerical solver definition 
basis = 'Bernstein';                   % Polynomial basis to be use. Alternatively: Legendre, Bernestein, Orthogonal Bernstein
time_distribution = 'Bernstein';       % Distribution of time intervals. Alternatively: Bernstein, Orthogonal Bernstein, Chebsyhev, Legendre, Linear, Newton-Cotes, Normal, Random, Trapezoidal
n = 50;                           % Polynomial order in the state vector expansion
m = 200;                               % Number of sampling points
 
solver = Solver(basis, n, time_distribution, m);

%% Problem definition 
L = 1;                          % Degree of the dynamics (maximum derivative order of the ODE system)
StateDimension = 1;             % Dimension of the configuration vector. Note the difference with the state vector
ControlDimension = 1;           % Dimension of the control vector

% Boundary conditions
k = 1;
S0 = [0];                    % Initial conditions
SF = [k];                    % Final conditions

% Parameter of the problem 
epsilon = (k/3)^(12) * (1-k^3) * (13*k^3-7);

% Create the problem
OptProblem = Problems.BallMizel(S0, SF, L, StateDimension, ControlDimension, epsilon);
    
%% Optimization
% Simple solution    
tic
[C, dV, u, t0, tf, tau, exitflag, output] = solver.solve(OptProblem);
toc 

% Average results 
iter = 0; 
time = zeros(1,iter);
setup.resultsFlag = false; 
for i = 1:iter
    tic 
    [C, dV, u, t0, tf, tau, exitflag, output] = solver.solve(OptProblem);
    time(i) = toc;
end

time = mean(time);

%% Plots
% Descend representation
figure;
hold on
plot(tau, C(1,:))
plot(tau, k*tau.^(2/3))
xlabel('Flight time')
ylabel('$X$ coordinate')
legend('Numerical', 'Analytical')
hold off
grid on; 

figure
hold on
plot(tau, C(2,:))
xlabel('Flight time')
ylabel('$Y$ coordinate')
hold off
grid on;

% Propulsive acceleration plot
figure_propulsion = figure;
hold on
plot(tau, u, 'LineWidth', 0.3)
xlabel('Flight time')
ylabel('$\mathbf{u}$')
grid on;