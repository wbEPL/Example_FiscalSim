mata:

function indirect(a,cp,shock,vatable,exempt)

{
	
alpha_cp=diag(cp) 

alpha_vat=diag(vatable) 

alpha_exempt=diag(exempt)

K=pinv(I(cols(alpha_vat))-  alpha_cp*a)

indirect=shock*alpha_vat*a*alpha_exempt*K
	
return(indirect)
	
}

end







