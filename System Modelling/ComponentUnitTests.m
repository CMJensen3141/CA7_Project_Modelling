Length = 10; rho = 1; Area = 0.5; Diameter = 1.5; g = 9.82; eta = 0.03; Reynolds = 125000; kf = 1.8; h = -3;


fooPipe = PipeComponent(Length,rho,Area,Diameter,g,eta,Reynolds,kf,h) % Every object property except mus and dps should be nonzero

fooValve = ValveComponent('foo',1)

fooPump = PumpComponent(2,4)