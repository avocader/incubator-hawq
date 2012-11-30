/*
 * Note: this file originally auto-generated by mib2c using
 *       version : 1.12 $ of : mfd-data-access.m2c,v $
 *
 * $Id: rdbmsSrvParamTable_data_access.h,v 1.1 2007/04/18 03:33:38 eggyknap Exp $
 */
#ifndef RDBMSSRVPARAMTABLE_DATA_ACCESS_H
#define RDBMSSRVPARAMTABLE_DATA_ACCESS_H

#ifdef __cplusplus
extern "C" {
#endif


/* *********************************************************************
 * function declarations
 */

/* *********************************************************************
 * Table declarations
 */
/**********************************************************************
 **********************************************************************
 ***
 *** Table rdbmsSrvParamTable
 ***
 **********************************************************************
 **********************************************************************/
/*
 * rdbmsSrvParamTable is subid 7 of rdbmsObjects.
 * Its status is Current.
 * OID: .1.3.6.1.2.1.39.1.7, length: 9
*/


    int rdbmsSrvParamTable_init_data(rdbmsSrvParamTable_registration_ptr rdbmsSrvParamTable_reg);


/*
 * TODO:180:o: Review rdbmsSrvParamTable cache timeout.
 * The number of seconds before the cache times out
 */
#define RDBMSSRVPARAMTABLE_CACHE_TIMEOUT   60

void rdbmsSrvParamTable_container_init(netsnmp_container **container_ptr_ptr,
                             netsnmp_cache *cache);
int rdbmsSrvParamTable_cache_load(netsnmp_container *container);
void rdbmsSrvParamTable_cache_free(netsnmp_container *container);

    int rdbmsSrvParamTable_row_prep( rdbmsSrvParamTable_rowreq_ctx *rowreq_ctx);


#ifdef __cplusplus
}
#endif

#endif /* RDBMSSRVPARAMTABLE_DATA_ACCESS_H */
