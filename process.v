`timescale 1ns / 1ps

module process(
    input clk,                  // clock 
    input [23:0] in_pix,        // valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
    output reg [5:0] row, col,   // selecteaza un rand si o coloana din imagine
    output reg out_we,           // activeaza scrierea pentru imaginea de iesire (write enable)
    output reg [23:0] out_pix,   // valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
    output reg mirror_done,      // semnaleaza terminarea actiunii de oglindire (activ pe 1)
    output reg gray_done,        // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
    output reg filter_done       // semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)
);

    // Declararea variabilelor
    reg[3:0] state = 0;
    reg[3:0] next_state = 0;
    reg[5:0] row_c = 0; // copia liniei pe care lucrez
    reg[5:0] col_c = 0; // copia coloanei pe care lucrez
    reg[5:0] row_ant = 0; // o variabila auxiliara in care salvez linia pe care interschimb valoarea pixelilor(pt oglindire)
    reg [23:0] in_pix_c;        
    reg [23:0] in_pix_c_1;
    reg [23:0] in_pix_c_2; // in functie de caz, salvez in aceste copii valoarea pixelului de pe pozitia [row,col] din imaginea de intrare
    reg[7:0] min = 0;
    reg[7:0] max = 0;
    reg[7:0] media = 0;

    always @(posedge clk) begin
        state <= next_state;
        row_c <= row;
        col_c <= col; // dupa fiecare stare copiile pozitiilor sunt actualizate cu valorile pozitiilor asupra carora am lucrat
    end

    always @(*) begin
        mirror_done = 0;
        gray_done = 0;

        case (state)
            0: begin // Starea initiala
                row = 0;
                col = 0;
                next_state = 1;
            end

            1: begin // MIRROR
                row_ant = 63 - row_c; // Se pastreaza in variabila auxiliara linia (din partea inferioara a matricei)
					 // cu care se face interschimbarea de pixeli
                row = row_c;
                col = col_c; // Setez pozitia pixelului din imaginea de intrare (din partea superioara)
                in_pix_c_1 = in_pix; // Pastrez valoarea pixelului de la pozitia data
                next_state = 2;
            end

            2: begin
                row = row_ant; 
                col = col_c; // Setez pozitia pixelului din imaginea de intrare (din partea inferioara)
                in_pix_c_2 = in_pix; // Pastrez valoarea pixelului de la pozitia data
                out_we = 1; // Fac posibila scrierea
                out_pix = in_pix_c_1; // Scriu la pozitia setata (din partea inferioara)
					 // valoarea pixelului pastrata (din partea superioara)
                next_state = 3;
            end

            3: begin // Analog starii 2 fac scrierea in partea superioara 
                row = 63 - row_ant;
                col = col_c;
                out_we = 1;
                out_pix = in_pix_c_2;
                next_state = 4;
            end // Se finalizeaza interschimbarea de pixeli pozitionati pe aceeasi coloana si pe linii simetric opuse

            4: begin // Liniile cresc astfel incat sa parcurga matricea pana la jumatate
                out_we = 0; // Nu scriu nimic in aceasta stare
                if (row_c == 31 && col_c == 63) begin
                    next_state = 5;  // Au fost parcurse toate pozitiile
                end else if (row_c < 31 && col_c == 63) begin
                    row = row_c + 1; 
                    col = 0; // Se trece pe prima coloana a randului urmator
                    next_state = 1;
                end else if (col_c < 63 && row_c <= 31) begin
                    row = row_c;
                    col = col_c + 1; // Se trece pe urmatoarea coloana a aceluiasi rand
                    next_state = 1;
                end
            end

            5: begin
                out_we = 0;
                mirror_done = 1; // Oglindirea a fost realizata
                next_state = 6;
                row = 0;
                col = 0; // Se pregateste pentru starea urmatoare
            end

            6: begin // Grayscale
                row = row_c;
                col = col_c; // Setez pozitia pixelului din imaginea de intrare
                in_pix_c = in_pix;
                next_state = 7;
            end

            7: begin
                // Se calculeaza minimul si maximul 
                if (in_pix_c[23:16] <= in_pix_c[15:8] && in_pix_c[23:16] <= in_pix_c[7:0]) begin
                    min = in_pix_c[23:16];
                    if (in_pix_c[15:8] <= in_pix_c[7:0])
                        max = in_pix_c[7:0];
                    else
                        max = in_pix_c[15:8]; // Cazul in care in_pix_c[23:26] este cel mai mic
                end else if (in_pix_c[15:8] <= in_pix_c[23:16] && in_pix_c[15:8] <= in_pix_c[7:0]) begin
                    min = in_pix_c[15:8];
                    if (in_pix_c[23:16] <= in_pix_c[7:0])
                        max = in_pix_c[7:0];
                    else
                        max = in_pix_c[23:16]; // Cazul in care in_pix_c[15:8] este cel mai mic
                end else if (in_pix_c[7:0] <= in_pix_c[23:16] && in_pix_c[7:0] <= in_pix_c[15:8]) begin
                    min = in_pix_c[7:0];
                    if (in_pix_c[23:16] <= in_pix_c[15:8])
                        max = in_pix_c[15:8];
                    else
                        max = in_pix_c[23:16]; // Cazul in care in_pix_c[7:0] este cel mai mic
                end
                next_state = 8;
            end

            8: begin
                media = (min + max) / 2;
                out_we = 1;
                out_pix[15:8] = media; // Scriu media la pozitia ceruta   
                out_pix[7:0] = 8'b0;
                out_pix[23:16] = 8'b0;    
                next_state = 9;
            end

              9: begin //Liniile cresc astfel incat sa se parcurga matricea in intregime
                out_we = 0; 
                if (row_c == 63 && col_c == 63) begin
                    next_state = 10;  
                end else if (row_c < 63 && col_c == 63) begin
                    row = row_c + 1; 
                    col = 0;
                    next_state = 6;
                end else if (col_c < 63 && row_c <= 63) begin
                    row = row_c;
                    col = col_c + 1; 
                    next_state = 6;
                end
            end

            10: begin
                out_we = 0;
                gray_done = 1; // Operatia de GrayScale a fost realizata 
         
				end

        endcase
    end  

endmodule 