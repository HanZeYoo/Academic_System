import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { JWT } from 'npm:google-auth-library@9'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { title, body, token } = await req.json()

    if (!token) {
      throw new Error('No FCM token provided')
    }

    // Get the service account from Supabase secrets
    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountStr) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT secret is missing')
    }

    const serviceAccount = JSON.parse(serviceAccountStr)

    // Authenticate and get an OAuth 2.0 token
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const authTokens = await jwtClient.getAccessToken()
    const accessToken = authTokens.token

    if (!accessToken) {
      throw new Error('Failed to get access token')
    }

    // Send the push notification
    const fcmPayload = {
      message: {
        token: token,
        notification: {
          title: title,
          body: body,
        },
      },
    }

    const projectId = serviceAccount.project_id
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    )

    const responseData = await response.json()

    if (!response.ok) {
      console.error('FCM API Error:', responseData)
      throw new Error(`FCM API Error: ${JSON.stringify(responseData)}`)
    }

    return new Response(JSON.stringify({ success: true, data: responseData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Function error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
