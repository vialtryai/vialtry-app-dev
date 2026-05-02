/**
 * Shopify Admin API — write operations for Auto-Fix Agent
 * Uses REST 2024-01 (simpler than GraphQL for product updates)
 */

const SHOPIFY_API_VERSION = '2024-01'

interface ShopifyProductUpdate {
  product: Record<string, unknown>
}

export async function updateShopifyProduct(
  shopDomain: string,
  accessToken: string,
  productId: string,          // numeric Shopify product ID (strip gid:// prefix)
  fields: Record<string, unknown>
): Promise<{ success: boolean; error?: string }> {
  const numericId = productId.replace(/\D/g, '')  // strip gid://shopify/Product/ prefix
  const url = `https://${shopDomain}/admin/api/${SHOPIFY_API_VERSION}/products/${numericId}.json`

  const body: ShopifyProductUpdate = { product: { id: numericId, ...fields } }

  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': accessToken,
    },
    body: JSON.stringify(body),
  })

  if (!res.ok) {
    const errorText = await res.text()
    return { success: false, error: `Shopify API ${res.status}: ${errorText}` }
  }

  return { success: true }
}

export async function getShopifyProduct(
  shopDomain: string,
  accessToken: string,
  productId: string
): Promise<{ product?: Record<string, unknown>; error?: string }> {
  const numericId = productId.replace(/\D/g, '')
  const url = `https://${shopDomain}/admin/api/${SHOPIFY_API_VERSION}/products/${numericId}.json`

  const res = await fetch(url, {
    headers: { 'X-Shopify-Access-Token': accessToken },
  })

  if (!res.ok) {
    return { error: `Shopify API ${res.status}` }
  }

  const data = await res.json()
  return { product: data.product }
}

// Map Vialtry attribute names → Shopify REST product fields
export const ATTRIBUTE_TO_SHOPIFY_FIELD: Record<string, string> = {
  title:            'title',
  description:      'body_html',
  seo_title:        'metafields',      // needs metafield endpoint
  seo_description:  'metafields',
  tags:             'tags',
  product_type:     'product_type',
  vendor:           'vendor',
  handle:           'handle',
}
