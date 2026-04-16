import { describe, expect, it } from 'vitest'
import { hello } from '../app/hello.js'

describe('{{DEV_NAME}}', () => {
  it('prints hello', () => {
    expect(hello()).toBe('Hello from {{DEV_NAME}}')
  })
})
