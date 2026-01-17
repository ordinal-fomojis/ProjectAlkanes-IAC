import { Vercel } from '@vercel/sdk'
import { CoreV1Api, KubeConfig } from '@kubernetes/client-node'

const TOKEN = process.env.VERCEL_TOKEN!
const DOMAIN = process.env.DOMAIN!
const SUB_DOMAIN = process.env.SUB_DOMAIN!
const TEAM_SLUG = process.env.TEAM_SLUG!

const vercel = new Vercel({ bearerToken: TOKEN })

const ip = await getIpAddress()
const record = await getDnsRecord()
await updateDnsRecord(record, ip)

async function updateDnsRecord(record: Awaited<ReturnType<typeof getDnsRecord>>, ip: string) {
  if (record != null && record.value === ip) {
    console.log(`DNS record already set to ${ip}. No changes required.`)
    return
  }

  if (record == null) {
    await createDnsRecord(ip)
    return
  }

  console.log(`DNS record exists but is out of date. Updating record to ${ip}.`)
  await vercel.dns.updateRecord({
    recordId: record.id,
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
