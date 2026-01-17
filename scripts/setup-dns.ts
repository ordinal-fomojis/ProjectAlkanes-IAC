import { Vercel } from '@vercel/sdk'
import { CoreV1Api, KubeConfig } from '@kubernetes/client-node'

function getRequiredEnv(name: string): string {
  const value = process.env[name]
  if (value == null || value === '') {
    throw new Error(`Missing required environment variable: ${name}`)
  }
  return value
}

const TOKEN = getRequiredEnv('VERCEL_TOKEN')
const DOMAIN = getRequiredEnv('DOMAIN')
const SUB_DOMAIN = getRequiredEnv('SUB_DOMAIN')
const TEAM_SLUG = getRequiredEnv('TEAM_SLUG')
const vercel = new Vercel({ bearerToken: TOKEN })

await updateDnsRecord()

async function updateDnsRecord() {
  const existingDnsRecord = await getDnsRecord()
  const ip = await getIpAddress()

  if (existingDnsRecord != null && existingDnsRecord.value === ip) {
    console.log(`DNS record already set to ${ip}. No changes required.`)
    return
  }

  if (existingDnsRecord == null) {
    await createDnsRecord(ip)
    return
  }

  console.log(`DNS record exists but is out of date. Updating record to ${ip}.`)
  await vercel.dns.updateRecord({
    recordId: existingDnsRecord.id,
    slug: TEAM_SLUG,
    requestBody: {
      value: ip
    }
  })
  console.log(`DNS record updated to ${ip}.`)
}

async function createDnsRecord(ip: string) {
  await vercel.dns.createRecord({
    domain: DOMAIN,
    slug: TEAM_SLUG,
    requestBody: {
      name: SUB_DOMAIN,
      type: 'A',
      value: ip
    }
  })
  console.log(`DNS record created for ${ip}.`)
}

async function getDnsRecord() {
  const response = await vercel.dns.getRecords({
    domain: DOMAIN,
    slug: TEAM_SLUG,
    limit: "100"
  })
  if (typeof response === 'string') {
    throw new Error(`Unknown DNS query response: ${response}`)
  }
  const records = response.records.filter(record => record.type === 'A' && record.name === SUB_DOMAIN)
  const record = records[0]
  if (records.length > 1) {
    throw new Error(`Found ${records.length} DNS records for ${SUB_DOMAIN}.${DOMAIN}. Expected 0 or 1.`)
  }
  return record
}

async function getIpAddress() {
  const kc = new KubeConfig()
  kc.loadFromDefault()
  const k8sApi = kc.makeApiClient(CoreV1Api)

  const services = await k8sApi.listNamespacedService({ namespace: 'gateway' })
  const ips = new Set(services.items
    .flatMap(service => service.status?.loadBalancer?.ingress?.map(ingress => ingress.ip) ?? [])
    .filter(ip => ip != null))
  const ip = Array.from(ips)[0]
  if (ips.size !== 1 || ip == null) {
    throw new Error(`Expected exactly one IP address. Found: [${Array.from(ips).join(', ')}]`)
  }
  return ip
}
