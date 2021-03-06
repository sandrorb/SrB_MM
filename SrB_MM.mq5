#property copyright   "Sandro Boschetti - 05/08/2020"
#property description "Programa implementado em MQL5/Metatrader5"
#property description "Realiza backtests do método MMDI idealizado por mim"
#property link        "http://lattes.cnpq.br/9930983261299053"
#property version     "1.00"


//#property indicator_separate_window
#property indicator_chart_window

//--- input parameters
#property indicator_buffers 1
#property indicator_plots   1

//---- plot RSIBuffer
#property indicator_label1  "SrB-MMDI"
#property indicator_type1   DRAW_ARROW //DRAW_LINE
#property indicator_color1  Red //clrGreen//Red
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- input parameters
input int periodo = 1;                        //número de períodos
input double capitalInicial = 30000.00;       //Capital Inicial
input int lote = 100;                         // 1 para WIN e 100 para ações
input bool reaplicar = false;                 //true: reaplicar o capital
input datetime t1 = D'2015.01.01 00:00:00';   //data inicial
input datetime t2 = D'2020.09.16 00:00:00';   //data final
//input datetime t2 = D'2020.08.09 00:00:01'; //data final
input double duracaoMax = 3.0;                //stop no tempo em períodos.

bool   comprado = false;
bool   jaCalculado = false;


//--- indicator buffers
double MyBuffer[];
//--- global variables
//bool tipoExpTeste = tipoExp;

int OnInit() {
   SetIndexBuffer(0,MyBuffer,INDICATOR_DATA);
   IndicatorSetString(INDICATOR_SHORTNAME,"SrB-MMDI("+string(periodo)+")");
   return(0);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
 
   int nOp = 0;
   double capital = capitalInicial;
   int nAcoes = 0;
   int nAcoesAux = 0;
   double precoDeCompra = 0;
   double lucroOp = 0;
   double lucroAcum = 0;
   double acumPositivo = 0;
   double acumNegativo = 0;
   int nAcertos = 0;
   int nErros = 0;
   double max = 0.0;
   double min = 0.0;
   
   // Para o cálculo do drawdown máximo
   double capMaxDD = capitalInicial;
   double capMinDD = capitalInicial;
   double rentDDMax = 0.00;
   double rentDDMaxAux = 0.00;
   
   // Essas duas variáveis não tem razão de ser neste método
   int nPregoes = 0;
   int nPregoesPos = 0;
   
   // Essas duas variáveis não tem razão de ser neste método
   datetime diaDaEntrada = time[0];
   double duracao = 0.0;
   
   // percentual dos trades que atingem a máxima. A outra parte sai pelo fechamento.
   double percRompMax = 0.5;
   
   int candleDaCompra = 0;
   
   double rentPorTradeAcum = 0.0;
   
   int checkNentradas = 0;
   int checkNsaidas = 0;
      
   for(int i=periodo+1; i<rates_total;i++){
   
      if (time[i]>=t1 && time[i]<t2) {

         nPregoes++;
         if(comprado){nPregoesPos++;}
      
         if (low[i-2]<low[i-1]) {
            min = low[i-2];
         }else{
            min = low[i-1];
         }
         //Para testarmos se o capital é suficiente para comprar 1 lote mínimo
         nAcoesAux = lote * floor(capital / (lote * min));
      
         // Se posiciona na compra
         if(!comprado && nAcoesAux>=lote){
           
            candleDaCompra = i;
            
            if( (open[i]>min && low[i]<min) || (open[i]<min && high[i]>min) ){
               precoDeCompra = min;
               nAcoes = lote * floor(capital / (lote * precoDeCompra));
               comprado = true;
               nOp++;
               diaDaEntrada = time[i];
               MyBuffer[i] = precoDeCompra;
               checkNentradas++;
            } 
         }
         
         
         duracao = i - candleDaCompra;
         
         if (high[i-2] > high[i-1]) {
            max = high[i-2];
         }else{
            max = high[i-1];
         }    
                 
         // Faz a venda
         if( (comprado && (high[i]>=max) && (duracao != 0)) || (comprado && (duracao>=duracaoMax))  ){

            if( duracao>=duracaoMax ){
               lucroOp = (close[i] - precoDeCompra) * nAcoes; // Excedido o tempo, encerrar ao fim do dia.              
            }else{
               lucroOp = (max - precoDeCompra) * nAcoes;
            }
            if(lucroOp>0){
               nAcertos++;
               acumPositivo = acumPositivo + lucroOp;
            }else{
               nErros++;
               acumNegativo = acumNegativo + lucroOp;
            }
            
            lucroAcum = lucroAcum + lucroOp;
            
            if(reaplicar == true){capital = capital + lucroOp;}
            
            rentPorTradeAcum = rentPorTradeAcum + (lucroOp / (nAcoes * precoDeCompra));

            // ************************************************
            // Início: Cálculo do Drawdown máximo
            if ((lucroAcum+capitalInicial) > capMaxDD) {
               capMaxDD = lucroAcum + capitalInicial;
               capMinDD = capMaxDD;
            } else {
               if ((lucroAcum+capitalInicial) < capMinDD){
                  capMinDD = lucroAcum + capitalInicial;
                  rentDDMaxAux = (capMaxDD - capMinDD) / capMaxDD;
                  if (rentDDMaxAux > rentDDMax) {
                     rentDDMax = rentDDMaxAux;
                  }
               }
            }
            // Fim: Cálculo do Drawdown máximo
            // ************************************************
            
            nAcoes = 0;
            precoDeCompra = 0;
            comprado = false;
            
            checkNsaidas++;
         } // fim do "if" da venda.
   } // fim do "if" do intervalo de tempo 
   } // fim do "for"
   
   
   double  dias = (t2-t1)/(60*60*24);
   double  anos = dias / 365.25;
   double meses = anos * 12;
   double rentTotal = 100.0*((lucroAcum+capitalInicial)/capitalInicial - 1);
   double rentMes = 100.0*(pow((1+rentTotal/100.0), 1/meses) - 1);

   string nome = Symbol();

   if(!jaCalculado){
      printf("Ativo: %s", nome);
      printf("Período de Teste: %s a %s", TimeToString(t1), TimeToString(t2));
      if(reaplicar){printf("Reinvestimento dos Lucros: SIM");}else{printf("Reinvestimento dos Lucros: NÃO");}
      printf("#Op: %d, #Pregões: %d, Capital Inicial: %.2f", nOp, nPregoes, capitalInicial);
      printf("Somatório dos Valores Positivos: %.2f e Negativos: %.2f e Diferença: %.2f", acumPositivo, acumNegativo, acumPositivo+acumNegativo);      
      printf("Lucro: %.2f, Capital Final: %.2f",  floor(lucroAcum), floor(capital));
      printf("#Acertos: %d (%.2f%%), #Erros: %d (%.2f%%)", nAcertos, 100.0*nAcertos/nOp,  nErros, 100.0*nErros/nOp);
      printf("Pay-off: %.2f e G/R: %.2f", - (acumPositivo/nAcertos) / (acumNegativo/nErros), -acumPositivo/acumNegativo);
      printf("#PregoesPosicionado: %d, #PregoesPosicionado/Op: %.2f", nPregoesPos, 1.0*nPregoesPos/nOp);
      printf("Rentabilidade Mensal: %.2f%% (juros compostos) ou %.2f%% (juros simples)", rentMes, rentTotal/meses);
      printf("Fração de pregões posicionado: %.2f%%", 100.0*nPregoesPos/nPregoes);
      if(reaplicar){
         printf("#Meses: %.0f, #Op/mes: %.2f, #Op/Pregão: %.2f, Rentabilidade/Op: %.2f%%", meses, nOp/meses, (nOp/meses)/22, rentMes/(nOp/meses));
      }else{
         printf("#Meses: %.0f, #Op/mes: %.2f, #Op/Pregão: %.2f, Rentabilidade/Op: %.2f%%", meses, nOp/meses, (nOp/meses)/22, rentTotal/nOp);
      }
      printf("Drawdown Máximo: %.2f%%", 100.0 * rentDDMax);
      printf("Rentabilidade média por Trade: %.4f%%: ", 100 * rentPorTradeAcum / nOp);
      printf("Ganho Percentual Médio: %.2f%% e Perda Percentual Média: %.2f%%",
             100*(acumPositivo/capital)/nAcertos, 100*(acumNegativo/capital)/nErros);
      
      //printf("#entradas: %d e #saídas: %d", checkNentradas, checkNsaidas);
      //printf("");
   }
   jaCalculado = true;

   return(rates_total);
}

