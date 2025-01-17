%% Project: 
% Date: 01/02/22

%% Main script
% Version 5 
% Following the paper "Initial design..." by Fan et. al

% This script aims to perform trajectory design optimisation processes
% based on Bernstein polynomials collocation methods

%% Graphics
set_graphics(); 

animations = 0;     % Set to 1 to generate the gif
fig = 1;            % Figure start number

%% Variables to be defined for each run
m = 100;                                 % Number of discretization points
time_distribution = 'Linear';            % Distribution of time intervals
sigma = 1;                               % If normal distribution is selected

%% Collocation method 
% Order of Bezier curve functions for each coordinate
n = [5 5];

%% Initial definitions
% Generate the time interval discretization distribution
switch (time_distribution)
    case 'Linear'
        tau = linspace(0,1,m);
    case 'Normal'
        pd = makedist('Normal');
        pd.sigma = sigma;
        xpd = linspace(-3,3,m);
        tau = cdf(pd,xpd);
    case 'Random'
        tau = rand(1, m);
        tau = sort(tau);
    case 'Gauss-Lobatto'
        i = 1:m;
        tau = -cos((i-1)/(m-1)*pi);
        tau = (tau-tau(1))/(tau(end)-tau(1));
    case 'Legendre-Gauss'
        tau = LG_nodes(0,1,m);
    case 'Bezier'
        tau = B_nodes(0,1,m);
    case 'Orthonormal Bezier'
        tau = OB_nodes(0,1,m);
    otherwise
        error('An appropriate time array distribution must be specified')
end

%% Boundary conditions of the problem
% Initial data
initial = [0;0]; 
final = [4; 1]; 
V = 1; 
w = [0.1; 0.1]; 

% Initial guess for the boundary control points
[tfapp, Papp, ~, Capp] = initial_approximation(V, tau, initial, final, 'Bernstein');

% Initial fitting for n+1 control points
[B, P0, C0] = initial_fitting(n, tau, Capp, 'Orthogonal Bernstein');

%% Optimisiation
% Initial guess 
x0 = [reshape(P0, [size(P0,1)*size(P0,2) 1])];
x0 = [x0; zeros(m,1); 100];

% Upper and lower bounds (empty in this case)
P_lb = [-Inf*ones(length(x0)-m-1,1); 0*ones(m,1); 0];
P_ub = [Inf*ones(length(x0)-m-1,1); pi/4*ones(m,1); 4*tfapp];

% Objective function
objective = @(x)flight_time(x);

% Linear constraints
A = [];
b = [];
Aeq = [];
beq = [];

% Non-linear constraints
nonlcon = @(x)constraints(V, w, tfapp, initial, final, n, m, x, B);

% Modification of fmincon optimisation options and parameters (according to the details in the paper)
options = optimoptions('fmincon', 'TolCon', 1e-6, 'Display', 'off', 'Algorithm', 'sqp');
options.MaxFunctionEvaluations = 1e6;

% Optimisation
[sol, dV, exitflag, output] = fmincon(objective, x0, A, b, Aeq, beq, P_lb, P_ub, nonlcon, options);

% Solution 
[c,ceq] = constraints(V, w, tfapp, initial, final, n, m, sol, B);
P = reshape(sol(1:end-m-1), [size(P0,1) size(P0,2)]);
C = evaluate_state(P,B,n);
theta = reshape(sol(end-m:end-1), [m 1]).';
tf = sol(end)*tfapp;
time = tau*tf;

% Dimensionalising
C(3:4,:) = C(3:4,:).*[cos(theta);sin(theta)]/tf;

%% Results
clc
display_results();
plots(); 
