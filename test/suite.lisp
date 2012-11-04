(defpackage :optima.test
  (:use :cl :optima :eos)
  (:shadowing-import-from :optima #:fail))
(in-package :optima.test)

(def-suite optima-test)
(in-suite optima-test)

(defmacro is-match (arg pattern)
  `(is-true (match ,arg (,pattern t))))

(defmacro is-not-match (arg pattern)
  `(is-false (match ,arg (,pattern t))))

(test constant-pattern
  ;; integer
  (is-match 1 1)
  ;; t
  (is-match t t)
  ;; nil
  (is-match nil nil)
  ;; keyword
  (is-match :foo :foo)
  ;; float
  (is-match 3.14 3.14)
  (is-not-match 0.999 1)
  ;; string
  (is-match "foo" "foo")
  ;; complex
  (is-match '(1 t 3.14 :foo "foo") '(1 t 3.14 :foo "foo")))

(test variable-pattern
  ;; simple bind
  (is (eql (match 1 (x x)) 1))
  ;; anonymous bind
  (is-match 1 _)
  ;; complex bind
  (is (eql (match '(1 2 3)
             ((list x y z) (+ x y z)))
           6)))

(test place-pattern
  ;; level 0
  (let ((z 1))
    (match z ((place x) (incf x)))
    (is (eql z 2)))
  ;; level 1
  (let ((z (cons 1 2)))
    (match z
      ((cons (place x) y)
       (incf x)
       (incf y)))
    (is (equal z (cons 2 2))))
  ;; level 2
  (let ((z (list (vector 1))))
    (match z
      ((list (vector (place x)))
       (incf x)))
    (is (equalp z (list (vector 2))))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass person ()
    ((name :initarg :name)
     (age :initarg :age)))
  (closer-mop:finalize-inheritance (find-class 'person))

  (defstruct (point (:predicate point-p))
    x y))

(test constructor-pattern
  ;; cons
  (is-match (cons 1 2) (cons 1 2))
  ;; vector
  (is-match (vector 1 2) (vector 1 2))
  ;; simple-vector
  (is-match (vector 1 2) (simple-vector 1 2))
  ;; class
  (let ((person (make-instance 'person :name "Bob" :age 31)))
    (is (equal (match person
                 ((person name age) (list name age)))
               '("Bob" 31)))
    (is-match person (person))
    (is-match person (person (name "Bob") (age 31)))
    (is-match person (person (name "Bob")))
    (is-match person (person (age 31)))
    (is-not-match person (person (name "Alice")))
    (is-not-match person (person (age 49)))
    (is-not-match 1 (person)))
  ;; structure
  (let ((point (make-point :x 1 :y 2)))
    (is (equal (match point
                 ((point- x y) (list x y)))
               '(1 2)))
    (is-match point (point))
    (is-match point (point (x 1) (y 2)))
    (is-match point (point (x 1)))
    (is-match point (point (y 2)))
    (is-not-match point (point (x 2)))
    (is-not-match 1 (point-))
    (is-match point (point-))
    (is-match point (point- (x 1) (y 2)))
    (is-match point (point- (x 1)))
    (is-match point (point- (y 2)))
    (is-not-match point (point- (x 2)))
    (is-not-match 1 (point-))))

(test derived-pattern
  ;; list
  (is-match (list 1 2 3) (list 1 2 3))
  ;; satisfies
  (is-match 1 (satisfies numberp))
  (is-not-match 1 (satisfies stringp))
  ;; eq, eql, equal, equalp
  (is-match :foo (eq :foo))
  (is-match 1 (eql 1))
  (is-match "foo" (equal "foo"))
  (is-match #(1) (equalp #(1)))
  ;; typep
  (is-match 1 (typep number))
  (is-match "foo" (typep string))
  (is-match :foo (typep (eql :foo)))
  (is-match 1 (typep (or string number)))
  (is-not-match 1 (typep (not t))))

(test guard-pattern
  (is-match 1 (guard _ t))
  (is-not-match 1 (guard _ nil))
  (is-match 1 (guard 1 t))
  (is-not-match 1 (guard 1 nil))
  (is-not-match 1 (guard 2 t))
  (is-match 1 (guard x (eql x 1)))
  ;; when/unless
  (is-match 1 (when t))
  (is-not-match 1 (when nil))
  (is-match 1 (unless nil))
  (is-match (cons 1 2) (cons _ (when (numberp *))))
  (is-not-match (cons 1 2) (cons _ (unless (numberp *))))
  (is-not-match 1 (unless t))
  (is-match 1 (and x (when (eql x 1))))
  (is-match 1 (and x (unless (eql x 2))))
  ;; when bind
  (is-match 1 (when (eql * 1)))
  (is-match 1 (unless (eql * 2)))
  ;; syntax sugar
  (is-true (match 1 (_ when t t)))
  (is-true (match 1 (_ unless nil t))))

(test not-pattern
  (is-match 1 (not 2))
  (is-not-match 1 (not 1))
  ;; double negation
  (is-not-match 1 (not (not (not 1))))
  (is-match 1 (not (not (not (not 1))))))

(test or-pattern
  (is-not-match 1 (or))
  (is-match 1 (or 1))
  (is-match 1 (or 1 1))
  (is-match 1 (or 1 2))
  (is-match 1 (or 2 1))
  (is-not-match 1 (or 2 3))
  (is-match 1 (or _))
  (is-match 1 (or _ _))
  (is-match 1 (or 2 (or 1)))
  (is-match 1 (or (or 1)))
  (is-not-match 1 (or (or (not 1))))
  ;; share check
  (signals error
    (macroexpand '(match (cons 1 2) ((or (cons x 2) (cons y 2))))))
  (is (not (null (macroexpand '(match (cons 1 2)
                                ((or (cons x 2) (cons x 2)))))))))

(test and-pattern
  (is-not-match 1 (and))
  (is-match 1 (and 1))
  (is-match 1 (and 1 1))
  (is-not-match 1 (and 1 2))
  (is-match 1 (and _))
  (is-match 1 (and _ _))
  (is-match 1 (and 1 (and 1)))
  (is-match 1 (and (and 1)))
  (is (eql (match 1 ((and 1 x) x)) 1))
  (is-not-match 1 (and (and (not 1)))))

(test match
  ;; empty
  (is-false (match 1))
  ;; values
  (is (equal (multiple-value-list (match 1 (1 (values 1 2 3))))
             '(1 2 3)))
  ;; fail
  (is-false (match 1
              (1 (fail))))
  (is-false (match 1
              (1 (fail))
              (1 t)))
  (is-true (match 1
             (1 (fail))
             (1 nil)
             (_ t)))
  (is (eql (match (cons 1 2)
             ((cons x y)
              (if (eql x 1)
                  (fail)
                  y))
             ((cons x 2)
              x))
           1))
  ;; linear pattern
  (signals error
    (macroexpand
     '(match (cons 1 2)
       ((cons x x) t))))
  (signals error
    (macroexpand
     '(match (list 1 (list 2 3))
       ((list x (list y x)) t))))
  (signals error
    (macroexpand
     '(match (list 1 (list 2 3))
       ((list x (list y y)) t))))
  (signals error
    (macroexpand
     '(match 1
       ((and x x) t))))
  (is-match 1 (and _ _))
  (is-match 1 (or * *)))

(test multiple-value-match
  (is (eql (multiple-value-match (values 1 2)
             ((2) 1)
             ((1 y) y))
           2))
  ;; fail
  (is-true (multiple-value-match (values 1 2)
             ((1 2) (fail))
             ((_ _) t)))
  ;; linear pattern
  (signals error
    (macroexpand
     '(multiple-value-match (values 1 2)
       ((x x) t))))
  (is-true (multiple-value-match 1
             ((_ _) t))))

(test ematch
  (is-true (ematch 1 (1 t)))
  (signals match-error
    (ematch 1 (2 t)))
  ;; fail
  (is-true (ematch 1
             (1 (fail))
             (_ t)))
  (signals match-error
    (ematch 1
      (1 (fail))
      (1 t)))
  ;; only once
  (let ((count 0))
    (flet ((f () (incf count)))
      (is (eql (handler-case (ematch (f) (0 t))
                 (match-error (e)
                   (first (match-error-values e))))
               1)))))

(test multiple-value-ematch
  (signals match-error
    (multiple-value-ematch (values 1 2)
      ((2 1) t)))
  ;; fail
  (signals match-error
    (multiple-value-ematch (values 1 2)
      ((1 2) (fail))))
  ;; only once
  (let ((count 0))
    (flet ((f () (incf count)))
      (is (eql (handler-case (multiple-value-ematch (values (f)) ((0) t))
                 (match-error (e)
                   (first (match-error-values e))))
               1)))))

(test cmatch
  (is-true (cmatch 1 (1 t)))
  (is-false (handler-bind ((match-error #'continue))
              (cmatch 1 (2 t))))
  ;; only once
  (let ((count 0))
    (flet ((f () (incf count)))
      (is (eql (handler-case (cmatch (f) (0 t))
                 (match-error (e)
                   (first (match-error-values e))))
               1)))))

(test multiple-value-cmatch
  (is-false (handler-bind ((match-error #'continue))
              (multiple-value-cmatch (values 1 2)
                ((2 1) t))))
  ;; only once
  (let ((count 0))
    (flet ((f () (incf count)))
      (is (eql (handler-case (multiple-value-cmatch (values (f)) ((0) t))
                 (match-error (e)
                   (first (match-error-values e))))
               1)))))

(test issue39
  (is (eql (match '(0) ((list x) x))
           0))
  (is (eql (match '(0) ((list (and x (when (numberp x)))) x))
           0)))

(test issue38
  (signals error
    (macroexpand '(match 1 ((or (place x) (place x)))))))

(test issue31
  (is (equal (match '(1 2 3 4)
               ((or (list* (and (typep symbol) x) y z)
                    (list* y x z))
                (list x y z)))
             '(2 1 (3 4)))))