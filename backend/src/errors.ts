import { Prisma } from '@prisma/client';
import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';

export class AppError extends Error {
  constructor(
    public status: number,
    message: string,
    public code = 'REQUEST_FAILED',
  ) {
    super(message);
  }
}

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof ZodError) {
    return void res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid request',
        details: error.flatten(),
      },
    });
  }
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2002') {
      return void res.status(409).json({
        error: {
          code: 'DUPLICATE_RECORD',
          message: 'A record with these details already exists',
        },
      });
    }
    if (error.code === 'P2025') {
      return void res.status(404).json({
        error: { code: 'NOT_FOUND', message: 'The requested record was not found' },
      });
    }
    if (error.code === 'P2034') {
      return void res.status(409).json({
        error: {
          code: 'CONCURRENT_UPDATE',
          message: 'The record changed during this request; refresh and try again',
        },
      });
    }
  }
  const value = error instanceof AppError
    ? error
    : new AppError(500, 'Internal server error', 'INTERNAL_ERROR');
  res.status(value.status).json({
    error: { code: value.code, message: value.message },
  });
};
