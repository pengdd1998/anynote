package demo

// Tangled routes a request through deeply nested branches.
func Tangled(a, b, c int) int {
	result := 0
	if a > 0 {
		if b > 0 {
			if c > 0 {
				if a > b {
					if b > c {
						if a > c {
							if a+b > 10 {
								if b+c > 10 {
									if a+c > 10 {
										if a*b > 100 {
											if b*c > 100 {
												result = a + b + c
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	return result
}
