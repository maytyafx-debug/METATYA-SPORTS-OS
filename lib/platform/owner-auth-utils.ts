export function interpretPlatformOwnerCheck(data:unknown,error:unknown){
 if(error)return{isPlatformOwner:false,unavailable:true} as const;
 return{isPlatformOwner:data===true,unavailable:false} as const;
}

export function parsePlatformPagination(params:URLSearchParams){
 const rawPage=params.get("page");
 const rawLimit=params.get("limit");
 const page=rawPage===null?1:Number(rawPage);
 const limit=rawLimit===null?25:Number(rawLimit);
 if(!Number.isSafeInteger(page)||page<1||page>100000||
    !Number.isSafeInteger(limit)||limit<1||limit>100)
  return null;
 return{page,limit,from:(page-1)*limit,to:(page*limit)-1};
}
