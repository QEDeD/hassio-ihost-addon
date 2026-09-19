"""Compare the recovery export against the retained normal candidate, offline."""
import hashlib,json,pathlib,re,sys
recovery,candidate=map(pathlib.Path,sys.argv[1:3])
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def defines(p):
    return {k:re.sub(r'[\s()]','',v) for k,v in re.findall(r'^#define\s+(\w+)[ \t]+([^\n]+)',p.read_text(),re.M)}
def body(p,name):
    return re.search(r'void '+name+r'\(void\)\s*\{([^}]+)\}',p.read_text()).group(1).strip()
checks={}
for f in ['nvm3_default_config.h','psa_crypto_config.h','sl_cpc_security_config.h']:
    a,b=recovery/'config'/f,candidate/'config'/f
    assert defines(a)==defines(b),f
    checks[f]={'normalized_defines_equal':True,'recovery_sha256':sha(a),'candidate_sha256':sha(b)}
for p in [recovery,candidate]:
    s=(p/'autogen/sli_psa_config_autogen.h').read_text()
    assert '#define SL_PSA_ITS_MAX_FILES (1 + SL_PSA_ITS_USER_MAX_FILES)' in s
    assert 'MBEDTLS_PSA_CRYPTO_KEY_ID_ENCODES_OWNER' not in s
    assert 'TFM_CONFIG_SL_SECURE_LIBRARY' not in (p/'autogen/sl_component_catalog.h').read_text()
event='autogen/sl_event_handler.c'
assert body(recovery/event,'sl_platform_init')==body(candidate/event,'sl_platform_init')
assert body(candidate/event,'sl_service_init').startswith(body(recovery/event,'sl_service_init'))
checks['initialization']={'platform_identical':True,'service_sequence_is_candidate_prefix':True,'omitted_service_calls':['sli_protocol_crypto_init','sli_aes_seed_mask'],'network_stack_init_absent':True}
symbols=(recovery/'evidence/symbols.txt').read_text()
for sym in ['nvm3_eraseAll','sl_cpc_security_register_unbind_notification','sl_cpc_security_unregister_unbind_notification']:
    assert not re.search(r'\b'+sym+r'$',symbols,re.M),sym
startup=(recovery/'evidence/cpc_app_init-disassembly.txt').read_text()
assert re.search(r'<cpc_app_init>:\s*\n\s*[\da-f]+:\s+4770\s+bx\s+lr',startup)
unbind=(recovery/'evidence/sl_cpc_security_unbind-disassembly.txt').read_text()
assert unbind.count('@ 0x4200')==3
assert '<psa_destroy_persistent_key>' in unbind and '<psa_is_key_present_in_storage>' in unbind
checks['linked_deletion']={'startup_no_op':True,'target_key':'0x4200','presence_check_before_after':True,'no_erase_all_or_observer_registration_symbols':True,'scope':'static source/binary evidence; not executed on hardware'}
print(json.dumps(checks,indent=2))
