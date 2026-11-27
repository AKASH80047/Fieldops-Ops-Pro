const bearer = [{ bearerAuth: [] }];
const id = {
  in: 'path',
  name: 'id',
  required: true,
  schema: { type: 'string', format: 'uuid' },
} as const;

export const openapi = {
  openapi: '3.0.3',
  info: {
    title: 'FieldOps Pro API',
    version: '1.1.0',
    description:
      'Tenant-scoped field service API. Payment, refund, cash verification, settlement and payout transitions are validated by the server and audited.',
  },
  servers: [{ url: '/api/v1' }],
  components: {
    securitySchemes: {
      bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
    },
    schemas: {
      Error: {
        type: 'object',
        properties: {
          error: {
            type: 'object',
            properties: {
              code: { type: 'string' },
              message: { type: 'string' },
              details: { type: 'object' },
            },
          },
        },
      },
    },
  },
  security: bearer,
  paths: {
    '/auth/login': {
      post: {
        security: [],
        summary: 'Authenticate an active user and active business membership',
        responses: {
          '200': { description: 'Access and refresh tokens issued' },
          '401': { description: 'Invalid credentials' },
          '403': { description: 'Account or membership inactive' },
        },
      },
    },
    '/services': {
      get: {
        summary: 'List active tenant services',
        responses: { '200': { description: 'Paginated services' } },
      },
    },
    '/bookings': {
      get: {
        summary: 'List the authenticated customer bookings',
        responses: { '200': { description: 'Bookings' } },
      },
      post: {
        summary: 'Create a customer booking',
        responses: {
          '201': { description: 'Booking created' },
          '422': { description: 'Validation failure' },
        },
      },
    },
    '/technician/jobs': {
      get: {
        summary: 'List active assignments for an approved technician',
        responses: { '200': { description: 'Assigned jobs' } },
      },
    },
    '/technician/invoices/{id}/cash-collection': {
      post: {
        summary: 'Submit a tenant-owned cash receipt for Admin verification',
        parameters: [
          id,
          {
            in: 'header',
            name: 'Idempotency-Key',
            required: true,
            schema: { type: 'string' },
          },
        ],
        responses: {
          '201': { description: 'Cash collection submitted; payment remains pending' },
          '403': { description: 'Technician is not assigned to the invoiced job' },
        },
      },
    },
    '/technician/payout-requests': {
      get: {
        summary: 'List the authenticated technician payout requests',
        responses: { '200': { description: 'Payout requests' } },
      },
      post: {
        summary: 'Lock all available ledger entries into one payout request',
        parameters: [
          {
            in: 'header',
            name: 'Idempotency-Key',
            required: true,
            schema: { type: 'string' },
          },
        ],
        responses: {
          '201': { description: 'Payout request created atomically' },
          '409': { description: 'No earnings or another payout is open' },
        },
      },
    },
    '/admin/dashboard': {
      get: {
        summary: 'Get tenant-scoped operational and finance totals',
        responses: { '200': { description: 'Dashboard summary' } },
      },
    },
    '/admin/service-categories': {
      get: {
        summary: 'List service categories, including disabled categories',
        responses: { '200': { description: 'Paginated categories' } },
      },
      post: {
        summary: 'Create a service category',
        responses: { '201': { description: 'Category created and audited' } },
      },
    },
    '/admin/service-categories/{id}': {
      patch: {
        summary: 'Update a tenant service category',
        parameters: [id],
        responses: { '200': { description: 'Category updated' } },
      },
      delete: {
        summary: 'Soft-delete an unused category',
        parameters: [id],
        responses: {
          '204': { description: 'Category deleted' },
          '409': { description: 'Category still has active services' },
        },
      },
    },
    '/admin/services': {
      get: {
        summary: 'List tenant services for management',
        responses: { '200': { description: 'Paginated services' } },
      },
      post: {
        summary: 'Create service pricing, skills and area coverage',
        responses: { '201': { description: 'Service created and audited' } },
      },
    },
    '/admin/services/{id}': {
      patch: {
        summary: 'Update a tenant service',
        parameters: [id],
        responses: { '200': { description: 'Service updated' } },
      },
      delete: {
        summary: 'Soft-delete a service',
        parameters: [id],
        responses: { '204': { description: 'Service deleted' } },
      },
    },
    '/admin/complaints': {
      get: {
        summary: 'List and filter tenant complaints',
        responses: { '200': { description: 'Paginated complaints' } },
      },
    },
    '/admin/complaints/{id}/start': {
      post: {
        summary: 'Move an open or reopened complaint to in progress',
        parameters: [id],
        responses: { '200': { description: 'Complaint started and audited' } },
      },
    },
    '/admin/complaints/{id}/resolve': {
      post: {
        summary: 'Resolve an in-progress complaint with required resolution text',
        parameters: [id],
        responses: { '200': { description: 'Complaint resolved and customer notified' } },
      },
    },
    '/admin/complaints/{id}/reopen': {
      post: {
        summary: 'Reopen a resolved complaint with a reason',
        parameters: [id],
        responses: { '200': { description: 'Complaint reopened and audited' } },
      },
    },
    '/admin/payments': {
      get: {
        summary: 'List online and cash payments with verification state',
        responses: { '200': { description: 'Paginated payments' } },
      },
    },
    '/admin/payments/{id}/refunds': {
      post: {
        summary: 'Create a bounded, idempotent refund request',
        parameters: [
          id,
          {
            in: 'header',
            name: 'Idempotency-Key',
            required: true,
            schema: { type: 'string' },
          },
        ],
        responses: { '201': { description: 'Refund request created' } },
      },
    },
    '/admin/refunds/{id}/process': {
      post: {
        summary: 'Process an approved refund through the configured provider',
        parameters: [id],
        responses: {
          '200': { description: 'Provider-confirmed refund recorded' },
          '503': { description: 'Refund provider is not configured' },
        },
      },
    },
    '/admin/cash-collections/{id}/verify': {
      post: {
        summary: 'Verify a cash receipt and mark its payment paid on the server',
        parameters: [id],
        responses: { '200': { description: 'Cash payment verified and audited' } },
      },
    },
    '/admin/settlements/{id}': {
      patch: {
        summary: 'Approve, hold or reverse a technician ledger entry',
        parameters: [id],
        responses: {
          '200': { description: 'Settlement state updated' },
          '409': { description: 'Payment, complaint or payout lock prevents transition' },
        },
      },
    },
    '/admin/payouts/{id}/approve': {
      post: {
        summary: 'Approve a payout backed by locked ledger allocations',
        parameters: [id],
        responses: { '200': { description: 'Payout approved' } },
      },
    },
    '/admin/payouts/{id}/mark-paid': {
      post: {
        summary: 'Record an externally confirmed payout reference and settle locked entries',
        parameters: [id],
        responses: { '200': { description: 'Payout and ledger entries marked paid' } },
      },
    },
    '/admin/jobs/{id}/assign-technician': {
      post: {
        summary: 'Assign an approved, online, in-tenant technician',
        parameters: [id],
        responses: { '201': { description: 'Technician assigned atomically' } },
      },
    },
  },
};
