function [x2,y2,audiogram_type]=get_audiogram(num)

switch num
    case 1
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [25 25 25 35 25 30];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Mild hearing loss at all frequencies';
    case 2
        x1  = [250 500 1000 2000 3000 4000 6000 8000];
        y1  = [5 0 0 5 15 35 25 5];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Mild hearing loss at high frequencies';
    case 3
        x1  = [0 250 500 1000 2000 4000 8000];
        y1  = [35 35 35 30 24 15 20];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Mild to moderate hearing loss at low frequencies';
    case 4
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [10 15 25 40 50 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Moderate hearing loss at high frequencies';
    case 5
        x1  = [0 250 500 1000 2000 4000 8000];
        y1  = [90 90 95 85 95 90 95];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Profound HEARING LOSS';
    case 6
        x1  = [250 500 1000 2000 3000 4000 6000 8000];
        y1  = [15 25 35 55 75 95 75 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Severe hearing loss in the middle to high frequencies';
    case 7
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [90 90 95 95 90 110];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='profound loss Right Ear';
    case 8
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [85 85 95 95 110 105];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='profound loss Left Ear';
    case 9
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [70 70 60 105 110 105];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='severe sensorineural HL Right';

    case 10
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [85 95 100 90 110 100];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='profound HL left';
    case 11
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [50 55 60 65 70 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderately severe SN hearing loss';
    case 12
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [55 50 55 60 60 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1)));
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2);
        audiogram_type='Moderate to Moderately severe SN hearing loss';
    case 13
        x1  = [250 500 1000 2000 4000 6000 8000];
        y1  = [60 75 75 65 65 80 90];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate lateralized 500, 2k ';
    case 14
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [75 80 95 105 105 105];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderately severe SNHL Laterized at 2k ';
    case 15
        x1  = [250 500 1000 2000 3000 4000 8000];
        y1  = [25 30 50 70 95 105 105];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type='Bilateral moderate SNHL  Right ear';
    case 16
        x1  = [250 500 1000 2000 4000 6000 8000];
        y1  = [45 45 55 50 40 105 100];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1)));
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2);
        audiogram_type='Bilateral moderate SNHL  Left ear';
    case 17
        x1  = [250 500 1000 2000 4000 6000 8000];
        y1  = [30 25 20 15 15 30 37];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Mild hearing loss  Right';
    case 18
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [30 25 15 20 25 25];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Mild hearing loss  Left';
    case 19
        x1  = [250 500 1000 2000 3000 4000 8000];
        y1  = [5 20 30 40 45 60 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Mild to moderately severe SNHL High frequency sloping';
    case 20
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [70  70 50 50 60 60];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate SNHL Right';
    case 21
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [85 80 70 65 85 95];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate SNHL Left';  
    case 22
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [40 35 35 35 35 48];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate ';
    case 23
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [30 25 35 30 35 25];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate '; 
    case 24
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [15 15 22 40 50 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate';
    case 25
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [50 50 45 60 50 60];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate ';
    case 26
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [45 45 50 55 55 75];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate ';        
    case 27
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [60 75 65 65 80 90];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type='Moderate '; 
    case 28
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [30 25 15 18 30 38];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Right';         
    case 29
        x1  = [250 500 1000 2000 4000 8000];
        y1  = [30 25 15 20 28 18];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2  = x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2  = x2(1:1024);
        y2  = interp1(x21,y1,x2); 
        audiogram_type=' Left'; 
    case 30
        x1=[250 500 1000 2000 4000 8000];
        y1 = [85 95 100 90 110 100];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type='profound HL left';
    case 31
        x1=[250 500 1000 2000 3000 4000 8000];
        y1 = [25 30 50 70 95 105 105];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type='Bilateral moderate SNHL  Right ear';
    case 32
        x1=[250 500 1000 2000 4000 6000 8000];
        y1 = [45 45 55 50 40 105 100];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1)));
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2);
        audiogram_type='Bilateral moderate SNHL  Left ear'; 
    case 33
        x1=[250 500 1000 2000 4000 8000];
        y1 = [90 90 95 95 90 110];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type='profound loss Right Ear';
    case 34    
        x1=[250 500 1000 2000 4000 8000];
        y1 = [85 85 95 95 110 105];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type='profound loss Left Ear';
        case 35
                x1=[0 250 500 1000 2000 4000 8000];
        y1 = [90 90 95 85 95 90 95];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type=' Profound HEARING LOSS';
    case 36
        x1=[250 500 1000 2000 3000 4000 6000 8000];
        y1 = [15 25 35 55 75 95 75 65];
        x21 = (x1-x1(1))/(2*(x1(end)-x1(1))); 
        x2=x21(1):(x21(end)-x21(1))/1024:x21(end);
        x2 = x2(1:1024);
        y2 = interp1(x21,y1,x2); 
        audiogram_type=' Severe hearing loss in the middle to high frequencies';

end

end