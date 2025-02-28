#lang racket

(require "pest-ast.rkt")

(struct Stk (open values))

(define (stk->list stk input)
  (map (lambda (pc)
         (list-ref input pc))
       (Stk-values stk)))

(define (print-type p type)
  (printf "Result: ~a\nInput: ~a \nConsumed: ~a\nStack: ~a\n"
          (if (Type-bool type) "Accept" "Error")
          (Params-input p)
          (take (Params-input p) (Type-sp type))
          (stk->list (Type-stk type) (Params-input p))))

(struct Params (expr input sp stk hash)) ;; expr  input stack hash

(struct Type (bool sp stk) #:transparent)

(define (process p)
  (let* ([_expr (Params-expr p)]
         [_input (Params-input p)]
         [_sp (Params-sp p)]
         [_stk (Params-stk p)]
         [_hash (Params-hash p)])

    (match _expr
      [(Sym ch) (cond [(> (length _input) _sp) (let* (
                                                      [bool (eq? ch (list-ref _input _sp))]
                                                      [sp (cond [bool (+ _sp 1)]
                                                                [else _sp])]
                                                      [stk (cond [(Stk-open _stk) (Stk #t (cons _sp (Stk-values _stk)))]
                                                                 [else _stk]
                                                                 )]
                                                      )
                                                 (Type bool sp stk))]
                      [else (Type #f _sp _stk)])]

      [(Any) (cond [(> (length _input) _sp) (let* (
                                                   [sp (+ _sp 1)]
                                                   [stk (cond [(Stk-open _stk) (Stk #t (cons _sp (Stk-values _stk)))]
                                                              [else _stk]
                                                              )]
                                                   )
                                              (Type #t sp stk))]
                   [else (Type #f _sp _stk)])]

      [(Cat l r) (let* (
                        [typel (process (Params l _input _sp _stk _hash))]
                        [bl (Type-bool typel)]
                        [spl (Type-sp typel)]
                        [stkl (Type-stk typel)]
                        )
                   (cond [bl (process (Params r _input spl stkl _hash))]
                         [else (Type #f spl stkl)]))]

      [(Alt l r) (let* (
                        [typel (process (Params l _input _sp _stk _hash))]
                        [bl (Type-bool typel)]
                        [spl (Type-sp typel)]
                        [stkl (Type-stk typel)]
                        )
                   (cond [bl (Type #t spl stkl)]
                         [else (process (Params r _input _sp _stk _hash))]))]

      [(Kln e) (let* (
                      [type (process (Params e _input _sp _stk _hash))]
                      [b (Type-bool type)]
                      [sp (Type-sp type)]
                      [stk (Type-stk type)]
                      )
                 (cond [b (process (Params (Kln e) _input sp stk _hash))]
                       [else (Type #t _sp _stk)]))]

      [(Rep e) (let* (
                      [type (process (Params e _input _sp _stk _hash))]
                      [b (Type-bool type)]
                      [sp (Type-sp type)]
                      [stk (Type-stk type)]
                      )
                 (cond [b (process (Params (Kln e) _input sp stk _hash))]
                       [else (Type #f _input _stk)]))]

      [(Opt e) (let* (
                      [type (process (Params e _input _sp _stk _hash))]
                      [b (Type-bool type)]
                      [sp (Type-sp type)]
                      [stk (Type-stk type)]
                      )
                 (cond [b (Type b sp stk)]
                       [else (Type #t _sp _stk)]))]

      [(Not e) (let* (
                      [type (process (Params e _input _sp _stk _hash))]
                      [b (Type-bool type)]
                      [sp (Type-sp type)]
                      [stk (Type-stk type)]
                      )
                 (cond [b (Type #f _sp _stk)]
                       [else (Type #t _sp _stk)]))]

      [(Keep e) (let* (
                       [type (process (Params e _input _sp _stk _hash))]
                       [b (Type-bool type)]
                       [sp (Type-sp type)]
                       [stk (Type-stk type)]
                       )
                  (cond [b (Type #t _sp stk)]
                        [else (Type #f _sp _stk)]))]

      [(RepN e n) (cond
                    [(> n 0) (let* (
                                    [type (process (Params e _input _sp _stk _hash))]
                                    [b (Type-bool type)]
                                    [sp (Type-sp type)]
                                    [stk (Type-stk type)]
                                    )
                               (cond [b (process (Params (RepN e (- n 1)) _input sp stk _hash))]
                                     [else (Type #f sp _stk)]))]
                    [else (Type #t _sp _stk)])]

      [(Min e n) (cond
                   [(> n 0) (let* (
                                   [type (process (Params e _input _sp _stk _hash))]
                                   [b (Type-bool type)]
                                   [sp (Type-sp type)]
                                   [stk (Type-stk type)]
                                   )
                              (cond [b (process (Params (Min e (- n 1)) _input sp stk _hash))]
                                    [else (Type #f sp stk)]))]
                   [(<= n 0) (let* (
                                    [type (process (Params e _input _sp _stk _hash))]
                                    [b (Type-bool type)]
                                    [sp (Type-sp type)]
                                    [stk (Type-stk type)]
                                    )
                               (cond [b (process (Params (Min e (- n 1)) _input sp stk _hash))]
                                     [else (Type #t sp stk)]))]
                   [else (Type #t _sp _stk)])]

      [(Max e n) (cond
                   [(> n 0) (let* (
                                   [type  (process (Params e _input _sp _stk _hash))]
                                   [b (Type-bool type)]
                                   [sp (Type-sp type)]
                                   [stk (Type-stk type)]
                                   )
                              (cond [b (process (Params (Max e (- n 1)) _input sp stk _hash))]
                                    [else (Type #t sp stk)]))]
                   [else (Type #t _sp _stk)])]

      [(Rng e min max) (cond
                         [(and (> min 0) (> max 0)) (let* (
                                                           [type  (process (Params e _input _sp _stk _hash))]
                                                           [b (Type-bool type)]
                                                           [sp (Type-sp type)]
                                                           [stk (Type-stk type)]
                                                           )
                                                      (cond [b (process (Params (Rng e (- min 1) (- max 1)) _input sp stk _hash))]
                                                            [else (Type #f sp stk)]))]

                         [(and (<= min 0) (> max 0)) (let* (
                                                            [type (process (Params e _input _sp _stk _hash))]
                                                            [b (Type-bool type)]
                                                            [sp (Type-sp type)]
                                                            [stk (Type-stk type)]
                                                            )
                                                       (cond [b (process (Params (Rng e (- min 1) (- max 1)) _input sp stk _hash))]
                                                             [else (Type #t sp stk)]))]
                         [else (Type #t _sp _stk)])]

      [(Push e) (let* (
                       [type (process (Params e _input _sp (Stk #t (Stk-values _stk)) _hash))]
                       [b (Type-bool type)]
                       [sp (Type-sp type)]
                       [stk (Type-stk type)]
                       [stkv (Stk-values stk)]
                       [stkb (Stk-open _stk)]
                       )
                  (Type b sp (Stk stkb stkv)))]

      [(Pop) (cond [(eq? (length (Stk-values _stk)) 0) (Type #f _sp _stk)]
                   [else (let* (
                                [stkv (cdr (Stk-values _stk))]
                                [stkc (list-ref _input (car (Stk-values _stk)))]
                                )
                           (cond [(eq? (list-ref _input _sp) stkc) (Type #t (+ _sp 1) (Stk (Stk-open _stk) stkv))]
                                 [else (Type #f _sp _stk)]))
                         ])]

      [(PopAll) (cond [(eq? (length (Stk-values _stk)) 0) (Type #t _sp _stk)]
                      [(<= (length _input) _sp) (Type #f _sp _stk)]
                      [else (let* (
                                   [stkv (cdr (Stk-values _stk))]
                                   [stkc (list-ref _input (car (Stk-values _stk)))]
                                   )
                              (cond [(eq? (list-ref _input _sp) stkc) (process (Params (PopAll) _input (+ _sp 1) (Stk (Stk-open _stk) stkv) _hash))]
                                    [else (Type #f _sp _stk)]))
                            ])]

      [(Peek) (cond [(eq? (length (Stk-values _stk)) 0) (Type #f _sp _stk)]
                    [else (let* (
                                 [stkc (list-ref _input (car (Stk-values _stk)))]
                                 )
                            (cond [(eq? (list-ref _input _sp) stkc) (Type #t (+ _sp 1) _stk)]
                                  [else (Type #f _sp _stk)]))
                          ])]

      [(PopAll) (cond [(eq? (length (Stk-values _stk)) 0) (Type #t _sp _stk)]
                      [(<= (length _input) _sp) (Type #f _sp _stk)]
                      [else (let* (
                                   [stkv (cdr (Stk-values _stk))]
                                   [stkc  (list-ref _input (car (Stk-values _stk)))]
                                   )
                              (cond [(eq? (list-ref _input _sp) stkc) (process (Params (PopAll) _input (+ _sp 1) (Stk (Stk-open _stk) stkv) _hash))]
                                    [else (Type #f _sp _stk)]))
                            ])]

      [(PeekAll) (cond [(eq? (length (Stk-values _stk)) 0) (Type #t _sp _stk)]
                       [(<= (length _input) _sp) (Type #f _sp _stk)]
                       [else (let* (
                                    [stkv (cdr (Stk-values _stk))]
                                    [stkc  (list-ref _input (car (Stk-values _stk)))]
                                    )
                               (cond [(eq? (list-ref _input _sp) stkc) (let* ([type (process (Params (PeekAll) _input (+ _sp 1) (Stk (Stk-open _stk) stkv) _hash))]
                                                                              [b (Type-bool type)]
                                                                              [sp (Type-sp type)]
                                                                              )
                                                                         (Type b sp _stk))]
                                     [else (Type #f _sp _stk)]))
                             ])]

      [(Drop) (cond [(eq? (length (Stk-values _stk)) 0) (Type #f _sp _stk)]
                    [else (let* (
                                 [stkb (Stk-open _stk)]
                                 [stkv (cdr (Stk-values _stk))]
                                 [stk (Stk stkb stkv)]
                                 )
                            (Type #t _sp stk))])]

      [(DropAll) (cond [(eq? (length (Stk-values _stk)) 0) (Type #f _sp _stk)]
                       [else (Type #t _sp '())]
                       )]

      [(Var v) (let ([e (hash-ref _hash v)])
                 (process (Params e _input _sp _stk _hash)))]

      [(Tonat) (length _stk)]
      )))

(define hash (make-hash))
(hash-set! hash 'bit (Alt (Sym 0) (Sym 1)))
(hash-set! hash 'byte (RepN (Var 'bit) 8))
(hash-set! hash 'type (Var 'byte))
(hash-set! hash 'length (RepN (Var 'byte) 2))
(hash-set! hash 'challenge (RepN (Var 'byte) 1))
(hash-set! hash 'padding (Kln (Var 'byte)))


(define p (Params
           (Cat (Var 'type) (Cat (Var 'length) (Cat (Var 'challenge) (Var 'padding)))) ;; expr
           '(1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0)
           0 ;; sp
           (Stk #f '()) ;; stk
           hash ;; hash
           ))

(define type (process p))

(print-type p type)