# See LICENSE for license details.

#*****************************************************************************
# baseline.S
#-----------------------------------------------------------------------------
#
# This is the most basic self checking test. If your simulator does not
# pass thiss then there is little chance that it will pass any of the
# more complicated self checking tests.
#
# We test 100 nops

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN


TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10
TEST_INSERT_NOPS_10


RVTEST_PASS

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END